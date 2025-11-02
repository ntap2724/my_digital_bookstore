<?php

namespace Tests\Feature;

use Tests\TestCase;
use ZipArchive;

class GenerateEssayPdfExtractionTest extends TestCase
{
    protected string $defaultPath;

    protected function setUp(): void
    {
        parent::setUp();
        $this->defaultPath = storage_path('app/essays/pdf_text_extraction_essay.docx');

        if (! is_dir(storage_path('app/essays'))) {
            mkdir(storage_path('app/essays'), 0755, true);
        }
    }

    protected function tearDown(): void
    {
        $files = glob(storage_path('app/essays/*.docx'));

        if (is_array($files)) {
            foreach ($files as $file) {
                @unlink($file);
            }
        }

        parent::tearDown();
    }

    public function test_command_generates_pdf_extraction_essay_with_defaults(): void
    {
        $this->artisan('essay:generate-pdf-extraction')->assertExitCode(0);

        $this->assertFileExists($this->defaultPath);
        $this->assertDocxContainsStrings($this->defaultPath, [
            'CÔNG NGHỆ TRÍCH XUẤT VĂN BẢN TỪ PDF',
            'VÀ ỨNG DỤNG TRONG HỆ THỐNG HIỆU SÁCH ĐIỆN TỬ',
            'PDF Text Extraction Technology &amp; Application in Digital Bookstore',
            'CHƯƠNG 1: GIỚI THIỆU',
            'CHƯƠNG 2: CƠ SỞ LÝ THUYẾT',
            'CHƯƠNG 3: THIẾT KẾ VÀ TRIỂN KHAI',
            'CHƯƠNG 4: KIỂM THỬ VÀ ĐÁNH GIÁ',
            'CHƯƠNG 5: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN',
            'TÀI LIỆU THAM KHẢO',
        ]);
    }

    public function test_command_respects_custom_metadata_and_output_path(): void
    {
        $relativeOutput = 'storage/app/essays/custom_pdf_extraction_essay.docx';
        $absoluteOutput = base_path($relativeOutput);

        $this->artisan('essay:generate-pdf-extraction', [
            '--student' => 'Trần Thị B',
            '--student-id' => '20210888',
            '--class' => 'CNTT-K63',
            '--instructor' => 'PGS.TS. Lê Văn D',
            '--university' => 'TRƯỜNG ĐẠI HỌC BÁCH KHOA',
            '--department' => 'KHOA CÔNG NGHỆ THÔNG TIN',
            '--output' => $relativeOutput,
        ])->assertExitCode(0);

        $this->assertFileExists($absoluteOutput);

        $this->assertDocxContainsStrings($absoluteOutput, [
            'TRƯỜNG ĐẠI HỌC BÁCH KHOA',
            'KHOA CÔNG NGHỆ THÔNG TIN',
            'Trần Thị B',
            '20210888',
            'CNTT-K63',
            'PGS.TS. Lê Văn D',
        ]);
    }

    public function test_essay_contains_pdf_specific_technical_content(): void
    {
        $this->artisan('essay:generate-pdf-extraction')->assertExitCode(0);

        $this->assertFileExists($this->defaultPath);
        $this->assertDocxContainsStrings($this->defaultPath, [
            'smalot/pdfparser',
            'ISO 32000',
            'parsePageSelection',
            'PdfTextExtractor',
            'text extraction',
            'page selection',
        ]);
    }

    protected function assertDocxContainsStrings(string $path, array $needles): void
    {
        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path) === true, 'Unable to open generated docx archive.');

        $xml = $zip->getFromName('word/document.xml');
        $zip->close();

        $this->assertNotFalse($xml, 'The generated docx is missing the main document content.');

        foreach ($needles as $needle) {
            $this->assertStringContainsString($needle, $xml, "Failed asserting that document contains '{$needle}'.");
        }
    }
}
