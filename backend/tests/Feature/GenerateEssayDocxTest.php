<?php

namespace Tests\Feature;

use Tests\TestCase;

class GenerateEssayDocxTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        if (!is_dir(storage_path('app/essays'))) {
            mkdir(storage_path('app/essays'), 0755, true);
        }
    }

    protected function tearDown(): void
    {
        $essaysDir = storage_path('app/essays');
        if (is_dir($essaysDir)) {
            $files = glob("$essaysDir/*.docx");
            if (is_array($files)) {
                foreach ($files as $file) {
                    @unlink($file);
                }
            }
        }

        parent::tearDown();
    }

    public function test_command_generates_document_with_default_options(): void
    {
        $this->artisan('essay:generate')
            ->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/he-thong-thu-vien-dien-tu.docx')));
    }

    public function test_command_generates_document_with_custom_title(): void
    {
        $this->artisan('essay:generate', [
            '--title' => 'Custom Essay Title',
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/custom-essay-title.docx')));
    }

    public function test_command_accepts_all_options(): void
    {
        $this->artisan('essay:generate', [
            '--title' => 'Test Essay',
            '--student' => 'John Doe',
            '--student-id' => '12345678',
            '--class' => 'CS101',
            '--course' => 'Software Engineering',
            '--instructor' => 'Dr. Smith',
            '--university' => 'Test University',
            '--department' => 'Computer Science',
            '--language' => 'en',
            '--citation' => 'ieee',
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/test-essay.docx')));
    }

    public function test_command_generates_document_in_english(): void
    {
        $this->artisan('essay:generate', [
            '--title' => 'English Essay',
            '--language' => 'en',
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/english-essay.docx')));
    }

    public function test_command_generates_document_in_vietnamese(): void
    {
        $this->artisan('essay:generate', [
            '--title' => 'Bài luận tiếng Việt',
            '--language' => 'vi',
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/bai-luan-tieng-viet.docx')));
    }

    public function test_command_respects_custom_output_path(): void
    {
        $customPath = 'custom/path/essay.docx';
        
        $dir = dirname(storage_path("app/$customPath"));
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        
        $this->artisan('essay:generate', [
            '--title' => 'Custom Path Essay',
            '--out' => $customPath,
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path("app/$customPath")));
        
        if (file_exists(storage_path("app/$customPath"))) {
            unlink(storage_path("app/$customPath"));
        }
        if (is_dir(storage_path('app/custom/path'))) {
            rmdir(storage_path('app/custom/path'));
        }
        if (is_dir(storage_path('app/custom'))) {
            rmdir(storage_path('app/custom'));
        }
    }

    public function test_command_outputs_file_path(): void
    {
        $this->artisan('essay:generate', [
            '--title' => 'Output Test Essay',
            '--language' => 'en',
        ])
            ->expectsOutput('Essay document generated successfully!')
            ->assertExitCode(0);
    }

    public function test_command_handles_markdown_file(): void
    {
        $markdownPath = base_path('docs/test-essay.md');
        
        if (!is_dir(dirname($markdownPath))) {
            mkdir(dirname($markdownPath), 0755, true);
        }
        
        $markdownContent = <<<'MD'
# Introduction

This is the introduction section.

## Background

Some background information here.

### Sub-section

Additional details.

## Problem Statement

The problem we are solving.
MD;
        
        file_put_contents($markdownPath, $markdownContent);
        
        $this->artisan('essay:generate', [
            '--title' => 'Markdown Essay',
            '--from-markdown' => $markdownPath,
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/markdown-essay.docx')));
        
        unlink($markdownPath);
        if (is_dir(dirname($markdownPath))) {
            rmdir(dirname($markdownPath));
        }
    }

    public function test_command_handles_non_existent_markdown_file(): void
    {
        $this->artisan('essay:generate', [
            '--title' => 'Non-existent Markdown',
            '--from-markdown' => 'non-existent-file.md',
        ])->assertExitCode(0);
        
        $this->assertTrue(file_exists(storage_path('app/essays/non-existent-markdown.docx')));
    }
}
