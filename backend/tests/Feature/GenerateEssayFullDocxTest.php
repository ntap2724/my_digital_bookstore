<?php

namespace Tests\Feature;

use Illuminate\Support\Str;
use Tests\TestCase;
use ZipArchive;

class GenerateEssayFullDocxTest extends TestCase
{
    protected string $defaultPath;

    protected function setUp(): void
    {
        parent::setUp();
        $this->defaultPath = storage_path('app/essays/my_digital_bookstore_essay.docx');

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

    public function test_command_generates_complete_document_with_defaults(): void
    {
        $this->artisan('essay:generate-full')->assertExitCode(0);

        $this->assertFileExists($this->defaultPath);
        $this->assertDocxContainsStrings($this->defaultPath, [
            'HỆ THỐNG HIỆU SÁCH ĐIỆN TỬ TRỰC TUYẾN',
            'My Digital Bookstore - Laravel 12 & Flutter 3',
            'CHƯƠNG 1: MỞ ĐẦU',
            'CHƯƠNG 4: TRIỂN KHAI HỆ THỐNG',
            'TÀI LIỆU THAM KHẢO',
        ]);
    }

    public function test_command_respects_custom_metadata_and_output_path(): void
    {
        $relativeOutput = 'storage/app/essays/custom_full_essay.docx';
        $absoluteOutput = base_path($relativeOutput);

        $this->artisan('essay:generate-full', [
            '--student' => 'Trần Văn Test',
            '--student-id' => '20210999',
            '--class' => 'CNTT-K65',
            '--course' => 'Lập trình web nâng cao',
            '--instructor' => 'PGS.TS. Nguyễn Thị C',
            '--university' => 'TRƯỜNG ĐẠI HỌC KINH TẾ QUỐC DÂN',
            '--department' => 'KHOA HỆ THỐNG THÔNG TIN',
            '--output' => $relativeOutput,
        ])->assertExitCode(0);

        $this->assertFileExists($absoluteOutput);

        $this->assertDocxContainsStrings($absoluteOutput, [
            'TRƯỜNG ĐẠI HỌC KINH TẾ QUỐC DÂN',
            'KHOA HỆ THỐNG THÔNG TIN',
            'Trần Văn Test',
            '20210999',
            'CNTT-K65',
            'PGS.TS. Nguyễn Thị C',
        ]);
    }

    protected function assertDocxContainsStrings(string $path, array $needles): void
    {
        $zip = new ZipArchive();
        $this->assertTrue($zip->open($path) === true, 'Unable to open generated docx archive.');

        $xml = $zip->getFromName('word/document.xml');
        $zip->close();

        $this->assertNotFalse($xml, 'The generated docx is missing the main document content.');

        $normalized = Str::ascii(strip_tags($xml));

        foreach ($needles as $needle) {
            $this->assertStringContainsString($needle, $xml, "Failed asserting that document contains '{$needle}'.");
        }
    }
}
