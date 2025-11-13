<?php

namespace App\Services;

use InvalidArgumentException;
use RuntimeException;
use Smalot\PdfParser\Document;
use Smalot\PdfParser\Parser;
use Spatie\PdfToImage\Pdf;
use thiagoalessio\TesseractOCR\TesseractOcrException;
use thiagoalessio\TesseractOCR\TesseractOCR;
use Throwable;

class PdfTextExtractor
{
    private const COMBINED_MIN_TEXT_LENGTH = 10;

    private readonly string $tesseractBinary;

    /**
     * @var list<string>
     */
    private readonly array $configuredLanguages;

    private readonly int $ocrTimeout;

    public function __construct(private readonly Parser $parser)
    {
        $config = config('services.tesseract', []);

        $this->tesseractBinary = (string) ($config['binary'] ?? 'tesseract');
        $languages = $config['languages'] ?? ['eng', 'vie'];
        $this->configuredLanguages = array_values(array_unique(array_map('strval', $languages)));
        $this->ocrTimeout = (int) ($config['timeout'] ?? 120);
    }

    /**
     * Extract embedded text from a PDF file for the given pages.
     *
     * @param  string  $pdfPath
     * @param  array<int>  $pages
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int
     * }
     */
    public function extractText(string $pdfPath, array $pages = []): array
    {
        $document = $this->parseDocument($pdfPath);
        $totalPages = $this->getTotalPages($document);
        $pagesToExtract = $this->normalizePages($pages, $totalPages);

        $pageResults = $this->collectEmbeddedPageResults($document, $pagesToExtract);
        $summary = $this->summarizeResults($pageResults, $pagesToExtract, $totalPages, 'text');

        return [
            'text' => $summary['text'],
            'total_pages' => $summary['total_pages'],
            'extracted_pages' => $summary['extracted_pages'],
            'page_count' => $summary['page_count'],
        ];
    }

    /**
     * Extract text from a PDF file using the specified method.
     *
     * @param  string  $pdfPath
     * @param  array<int>  $pages
     * @param  string  $method
     * @param  string  $language
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int,
     *     method_used: string,
     *     extraction_details: array{embedded_text_pages: int, ocr_pages: int, failed_pages: int},
     *     processing_time_seconds: float
     * }
     */
    public function extractWithMethod(string $pdfPath, array $pages, string $method, string $language): array
    {
        $startTime = microtime(true);

        $summary = match ($method) {
            'text' => $this->extractEmbeddedText($pdfPath, $pages),
            'ocr' => $this->extractWithOcr($pdfPath, $pages, $language),
            'combined' => $this->extractCombined($pdfPath, $pages, $language),
            default => throw new InvalidArgumentException("Invalid extraction method: {$method}"),
        };

        $summary['processing_time_seconds'] = round(microtime(true) - $startTime, 3);

        return $summary;
    }

    /**
     * Parse and return a PDF document instance for further processing.
     */
    public function parseDocument(string $pdfPath): Document
    {
        if (! is_readable($pdfPath)) {
            throw new InvalidArgumentException('PDF file not found.');
        }

        try {
            return $this->parser->parseFile($pdfPath);
        } catch (Throwable $exception) {
            throw new RuntimeException('Failed to read PDF file.', 0, $exception);
        }
    }

    /**
     * Extract text from an already parsed document.
     *
     * @param  array<int>  $pages
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int
     * }
     */
    public function extractFromDocument(Document $document, array $pages = []): array
    {
        $totalPages = $this->getTotalPages($document);
        $pagesToExtract = $this->normalizePages($pages, $totalPages);

        $pageResults = $this->collectEmbeddedPageResults($document, $pagesToExtract);
        $summary = $this->summarizeResults($pageResults, $pagesToExtract, $totalPages, 'text');

        return [
            'text' => $summary['text'],
            'total_pages' => $summary['total_pages'],
            'extracted_pages' => $summary['extracted_pages'],
            'page_count' => $summary['page_count'],
        ];
    }

    /**
     * Extract text using embedded text only.
     *
     * @param  string  $pdfPath
     * @param  array<int>  $pages
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int,
     *     method_used: string,
     *     extraction_details: array{embedded_text_pages: int, ocr_pages: int, failed_pages: int}
     * }
     */
    protected function extractEmbeddedText(string $pdfPath, array $pages): array
    {
        $document = $this->parseDocument($pdfPath);
        $totalPages = $this->getTotalPages($document);
        $pagesToExtract = $this->normalizePages($pages, $totalPages);

        $pageResults = $this->collectEmbeddedPageResults($document, $pagesToExtract);

        return $this->summarizeResults($pageResults, $pagesToExtract, $totalPages, 'text');
    }

    /**
     * Extract text using OCR only.
     *
     * @param  string  $pdfPath
     * @param  array<int>  $pages
     * @param  string  $language
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int,
     *     method_used: string,
     *     extraction_details: array{embedded_text_pages: int, ocr_pages: int, failed_pages: int}
     * }
     */
    protected function extractWithOcr(string $pdfPath, array $pages, string $language): array
    {
        $document = $this->parseDocument($pdfPath);
        $totalPages = $this->getTotalPages($document);
        $pagesToProcess = $this->normalizePages($pages, $totalPages);

        $pageResults = $this->collectOcrPageResults($pdfPath, $pagesToProcess, $language);

        return $this->summarizeResults($pageResults, $pagesToProcess, $totalPages, 'ocr');
    }

    /**
     * Extract text using embedded text with OCR fallback.
     *
     * @param  string  $pdfPath
     * @param  array<int>  $pages
     * @param  string  $language
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int,
     *     method_used: string,
     *     extraction_details: array{embedded_text_pages: int, ocr_pages: int, failed_pages: int}
     * }
     */
    protected function extractCombined(string $pdfPath, array $pages, string $language): array
    {
        $document = $this->parseDocument($pdfPath);
        $totalPages = $this->getTotalPages($document);
        $pagesToProcess = $this->normalizePages($pages, $totalPages);

        $pageResults = $this->collectEmbeddedPageResults($document, $pagesToProcess);

        $pagesNeedingOcr = [];
        foreach ($pagesToProcess as $pageNumber) {
            $text = trim((string) ($pageResults[$pageNumber]['text'] ?? ''));
            if (mb_strlen($text) < self::COMBINED_MIN_TEXT_LENGTH) {
                $pagesNeedingOcr[] = $pageNumber;
                $pageResults[$pageNumber]['success'] = false;
            }
        }

        if ($pagesNeedingOcr !== []) {
            $ocrResults = $this->collectOcrPageResults($pdfPath, $pagesNeedingOcr, $language);

            foreach ($pagesNeedingOcr as $pageNumber) {
                $pageResults[$pageNumber] = $ocrResults[$pageNumber] ?? [
                    'text' => '',
                    'method' => 'ocr',
                    'success' => false,
                ];
            }
        }

        return $this->summarizeResults($pageResults, $pagesToProcess, $totalPages, 'combined');
    }

    /**
     * Convert a PDF page to an image file.
     */
    protected function convertPdfPageToImage(string $pdfPath, int $page, ?Pdf $pdf = null): string
    {
        $pdfInstance = $pdf ?? $this->createPdfImageInstance($pdfPath);

        $tempDir = storage_path('app/temp/ocr');
        if (! is_dir($tempDir) && ! mkdir($tempDir, 0755, true) && ! is_dir($tempDir)) {
            throw new RuntimeException('Failed to prepare directory for OCR images.');
        }

        $imagePath = $tempDir.'/'.uniqid('ocr_', true)."_page_{$page}.png";

        try {
            $pdfInstance->setPage($page)
                ->setOutputFormat('png')
                ->setResolution(300)
                ->saveImage($imagePath);
        } catch (Throwable $exception) {
            throw new RuntimeException('Failed to convert PDF page to image', 0, $exception);
        }

        return $imagePath;
    }

    /**
     * Perform OCR on an image file.
     */
    protected function performOcr(string $imagePath, string $language): string
    {
        $languages = array_values(array_filter(explode('+', $language)));

        if ($languages === []) {
            throw new InvalidArgumentException('Language not supported.');
        }

        foreach ($languages as $lang) {
            if (! in_array($lang, $this->configuredLanguages, true)) {
                throw new InvalidArgumentException('Language not supported.');
            }
        }

        try {
            $tesseract = new TesseractOCR($imagePath);

            if ($this->tesseractBinary !== '') {
                $tesseract->executable($this->tesseractBinary);
            }

            $tesseract->lang(...$languages);

            $text = $tesseract->run($this->ocrTimeout);

            return trim($text);
        } catch (TesseractOcrException $exception) {
            throw new RuntimeException('OCR engine not available', 0, $exception);
        } catch (Throwable $exception) {
            throw new RuntimeException('OCR processing failed', 0, $exception);
        }
    }

    /**
     * Parse a user supplied page selection into a list of page numbers with strict validation.
     *
     * @param  string|null  $input
     * @param  int  $totalPages
     * @return array<int>
     */
    public function parsePageSelection(?string $input, int $totalPages): array
    {
        if ($totalPages < 1) {
            throw new InvalidArgumentException('PDF has no pages to extract.');
        }

        if ($input === null) {
            return [];
        }

        $trimmed = trim($input);

        if ($trimmed === '') {
            return [];
        }

        $sanitized = preg_replace('/\s+/', '', $trimmed) ?? '';

        if ($sanitized === '') {
            return [];
        }

        if (! preg_match('/^[\d,\-]+$/', $sanitized)) {
            throw new InvalidArgumentException('Invalid page format. Use only numbers, commas, and hyphens.');
        }

        $parts = explode(',', $sanitized);
        $pages = [];

        foreach ($parts as $part) {
            if ($part === '') {
                throw new InvalidArgumentException('Invalid page selection: empty segments are not allowed.');
            }

            if (str_contains($part, '-')) {
                if (substr_count($part, '-') !== 1) {
                    throw new InvalidArgumentException("Invalid range format: {$part}");
                }

                [$startRaw, $endRaw] = explode('-', $part);

                if ($startRaw === '' || $endRaw === '') {
                    throw new InvalidArgumentException("Invalid range format: {$part}");
                }

                if (! ctype_digit($startRaw) || ! ctype_digit($endRaw)) {
                    throw new InvalidArgumentException("Invalid range format: {$part}");
                }

                $start = (int) $startRaw;
                $end = (int) $endRaw;

                if ($start < 1 || $end < 1) {
                    throw new InvalidArgumentException("Page numbers must be positive: {$part}");
                }

                if ($start > $end) {
                    throw new InvalidArgumentException("Invalid range (start > end): {$part}");
                }

                if ($end > $totalPages) {
                    throw new InvalidArgumentException("Page {$end} exceeds total pages ({$totalPages})");
                }

                for ($page = $start; $page <= $end; $page++) {
                    $pages[] = $page;
                }

                continue;
            }

            if (! ctype_digit($part)) {
                throw new InvalidArgumentException("Invalid page number: {$part}");
            }

            $pageNumber = (int) $part;

            if ($pageNumber < 1) {
                throw new InvalidArgumentException("Page numbers must be positive: {$pageNumber}");
            }

            if ($pageNumber > $totalPages) {
                throw new InvalidArgumentException("Page {$pageNumber} exceeds total pages ({$totalPages})");
            }

            $pages[] = $pageNumber;
        }

        if (count($pages) > 1000) {
            throw new InvalidArgumentException('Cannot extract more than 1000 pages per request');
        }

        $pages = array_values(array_unique($pages));
        sort($pages);

        return $pages;
    }

    /**
     * Get the total number of pages and ensure the document is readable.
     */
    private function getTotalPages(Document $document): int
    {
        $totalPages = count($document->getPages());

        if ($totalPages < 1) {
            throw new RuntimeException('Failed to read PDF file.');
        }

        return $totalPages;
    }

    /**
     * @param  array<int>  $pages
     * @return array<int>
     */
    private function normalizePages(array $pages, int $totalPages): array
    {
        $pagesToExtract = $pages === [] ? range(1, $totalPages) : array_values(array_unique($pages));

        sort($pagesToExtract, SORT_NUMERIC);

        if (count($pagesToExtract) > 1000) {
            throw new InvalidArgumentException('Cannot extract more than 1000 pages per request');
        }

        foreach ($pagesToExtract as $pageNumber) {
            if ($pageNumber < 1 || $pageNumber > $totalPages) {
                throw new InvalidArgumentException("Page {$pageNumber} exceeds total pages ({$totalPages})");
            }
        }

        return $pagesToExtract;
    }

    /**
     * @param  array<int, array{text: string, method: string, success: bool}>  $pageResults
     * @param  array<int>  $pagesToProcess
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int,
     *     method_used: string,
     *     extraction_details: array{embedded_text_pages: int, ocr_pages: int, failed_pages: int}
     * }
     */
    private function summarizeResults(array $pageResults, array $pagesToProcess, int $totalPages, string $methodUsed): array
    {
        $orderedPages = $pagesToProcess;
        sort($orderedPages, SORT_NUMERIC);

        $embeddedCount = 0;
        $ocrCount = 0;
        $failedCount = 0;
        $textSegments = [];

        $defaultMethod = $methodUsed === 'ocr' ? 'ocr' : 'embedded';

        foreach ($orderedPages as $pageNumber) {
            $result = $pageResults[$pageNumber] ?? null;
            $method = $result['method'] ?? $defaultMethod;
            $method = $method === 'text' ? 'embedded' : $method;

            $text = trim((string) ($result['text'] ?? ''));
            $success = (bool) ($result['success'] ?? ($text !== ''));

            if ($success && $text !== '') {
                $textSegments[] = $text;

                if ($method === 'ocr') {
                    $ocrCount++;
                } else {
                    $embeddedCount++;
                }
            } else {
                $failedCount++;
            }
        }

        $combinedText = trim(implode("\n\n", $textSegments));

        return [
            'text' => $combinedText,
            'total_pages' => $totalPages,
            'extracted_pages' => array_values($orderedPages),
            'page_count' => count($orderedPages),
            'method_used' => $methodUsed,
            'extraction_details' => [
                'embedded_text_pages' => $embeddedCount,
                'ocr_pages' => $ocrCount,
                'failed_pages' => $failedCount,
            ],
        ];
    }

    /**
     * @return array<int, array{text: string, method: string, success: bool}>
     */
    private function collectEmbeddedPageResults(Document $document, array $pagesToProcess): array
    {
        $pdfPages = $document->getPages();
        $totalPages = count($pdfPages);
        $results = [];

        foreach ($pagesToProcess as $pageNumber) {
            $pageIndex = $pageNumber - 1;

            if (! isset($pdfPages[$pageIndex])) {
                throw new InvalidArgumentException("Page {$pageNumber} exceeds total pages ({$totalPages})");
            }

            $text = trim((string) $pdfPages[$pageIndex]->getText());

            $results[$pageNumber] = [
                'text' => $text,
                'method' => 'embedded',
                'success' => $text !== '',
            ];
        }

        return $results;
    }

    /**
     * @return array<int, array{text: string, method: string, success: bool}>
     */
    private function collectOcrPageResults(string $pdfPath, array $pagesToProcess, string $language): array
    {
        $pdf = $this->createPdfImageInstance($pdfPath);
        $results = [];

        foreach ($pagesToProcess as $pageNumber) {
            $imagePath = null;

            try {
                $imagePath = $this->convertPdfPageToImage($pdfPath, $pageNumber, $pdf);
                $text = $this->performOcr($imagePath, $language);
                $text = trim($text);

                $results[$pageNumber] = [
                    'text' => $text,
                    'method' => 'ocr',
                    'success' => $text !== '',
                ];
            } finally {
                if ($imagePath && file_exists($imagePath)) {
                    @unlink($imagePath);
                }
            }
        }

        return $results;
    }

    private function createPdfImageInstance(string $pdfPath): Pdf
    {
        try {
            return new Pdf($pdfPath);
        } catch (Throwable $exception) {
            throw new RuntimeException('Image processing not available', 0, $exception);
        }
    }
}
