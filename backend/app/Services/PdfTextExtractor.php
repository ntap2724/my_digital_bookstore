<?php

namespace App\Services;

use Smalot\PdfParser\Parser;

class PdfTextExtractor
{
    private Parser $parser;

    public function __construct()
    {
        $this->parser = new Parser();
    }

    public function extractText(string $pdfPath): array
    {
        if (!file_exists($pdfPath)) {
            throw new \RuntimeException('PDF file not found');
        }

        if (!is_readable($pdfPath)) {
            throw new \RuntimeException('PDF file is not readable');
        }

        try {
            $pdf = $this->parser->parseFile($pdfPath);
            
            $pages = $pdf->getPages();
            $pageCount = count($pages);
            
            $text = $pdf->getText();
            
            $text = trim($text);
            
            if (empty($text)) {
                throw new \RuntimeException('No text content found in PDF. The PDF may contain only images or scanned content.');
            }
            
            return [
                'text' => $text,
                'pages' => $pageCount,
            ];
        } catch (\Exception $e) {
            if (str_contains($e->getMessage(), 'No text content found')) {
                throw $e;
            }
            
            throw new \RuntimeException('Failed to extract text from PDF: ' . $e->getMessage());
        }
    }
}
