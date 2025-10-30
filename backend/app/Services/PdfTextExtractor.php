<?php

namespace App\Services;

use InvalidArgumentException;
use RuntimeException;
use Smalot\PdfParser\Document;
use Smalot\PdfParser\Parser;

class PdfTextExtractor
{
    public function __construct(private readonly Parser $parser)
    {
    }

    /**
     * Extract text from a PDF file for the given pages.
     *
     * @param  string  $pdfPath  Absolute path to the PDF file.
     * @param  array<int>  $pages  1-based page numbers to extract. Empty array means all pages.
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

        return $this->extractFromDocument($document, $pages);
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
        } catch (\Throwable $exception) {
            throw new RuntimeException('Failed to read PDF file.', 0, $exception);
        }
    }

    /**
     * Extract text from an already parsed document.
     *
     * @param  array<int>  $pages  1-based page numbers to extract. Empty array means all pages.
     * @return array{
     *     text: string,
     *     total_pages: int,
     *     extracted_pages: array<int, int>,
     *     page_count: int
     * }
     */
    public function extractFromDocument(Document $document, array $pages = []): array
    {
        $pdfPages = $document->getPages();
        $totalPages = count($pdfPages);

        if ($totalPages < 1) {
            throw new RuntimeException('Failed to read PDF file.');
        }

        $pagesToExtract = $pages === [] ? range(1, $totalPages) : $pages;

        if (count($pagesToExtract) > 1000) {
            throw new InvalidArgumentException('Cannot extract more than 1000 pages per request');
        }

        $extractedPages = [];
        $textSegments = [];

        foreach ($pagesToExtract as $pageNumber) {
            $pageIndex = $pageNumber - 1;

            if (! isset($pdfPages[$pageIndex])) {
                throw new InvalidArgumentException("Page {$pageNumber} exceeds total pages ({$totalPages})");
            }

            $text = trim((string) $pdfPages[$pageIndex]->getText());

            if ($text !== '') {
                $textSegments[] = $text;
            }

            $extractedPages[] = $pageNumber;
        }

        $combinedText = trim(implode("\n\n", $textSegments));

        return [
            'text' => $combinedText,
            'total_pages' => $totalPages,
            'extracted_pages' => $extractedPages,
            'page_count' => count($extractedPages),
        ];
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

        // Sanitization: remove every whitespace character before format validation to avoid hidden payloads.
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
}
