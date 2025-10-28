<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Str;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\PhpWord;
use PhpOffice\PhpWord\Shared\Converter;
use PhpOffice\PhpWord\SimpleType\Jc;
use PhpOffice\PhpWord\Element\Section;

class GenerateEssayDocx extends Command
{
    protected $signature = 'essay:generate
                            {--title= : Essay title}
                            {--student= : Student name}
                            {--student-id= : Student ID}
                            {--class= : Class name}
                            {--course= : Course name}
                            {--instructor= : Instructor name}
                            {--university= : University name}
                            {--department= : Department name}
                            {--language=vi : Language (vi|en)}
                            {--citation=apa : Citation style (apa|ieee)}
                            {--out= : Output path}
                            {--from-markdown= : Parse content from a Markdown file}';

    protected $description = 'Generate a .docx essay document with standard academic formatting.';

    protected PhpWord $phpWord;
    protected array $translations = [];
    protected string $language = 'vi';
    protected string $citation = 'apa';
    protected array $headingCounters = [1 => 0, 2 => 0, 3 => 0];

    public function handle(): int
    {
        $this->language = $this->normalizeLanguage($this->option('language'));
        $this->citation = $this->normalizeCitation($this->option('citation'));

        $this->loadTranslations();
        $options = $this->resolveOptions();

        $this->phpWord = new PhpWord();
        $this->configureDocument();

        $markdownPath = $this->resolveMarkdownPath($this->option('from-markdown'));
        $this->buildDocument($options, $markdownPath);

        $outputPath = $this->getOutputPath($options['title']);
        IOFactory::createWriter($this->phpWord, 'Word2007')->save($outputPath);

        $this->info($this->trans('success_message'));
        $this->line(realpath($outputPath));

        return Command::SUCCESS;
    }

    protected function normalizeLanguage(?string $language): string
    {
        return in_array($language, ['en', 'vi'], true) ? $language : 'vi';
    }

    protected function normalizeCitation(?string $citation): string
    {
        return in_array($citation, ['apa', 'ieee'], true) ? $citation : 'apa';
    }

    protected function resolveOptions(): array
    {
        return [
            'title' => $this->option('title') ?: $this->trans('default_title'),
            'student' => $this->option('student') ?: $this->trans('default_student'),
            'student_id' => $this->option('student-id') ?: '12345678',
            'class' => $this->option('class') ?: $this->trans('default_class'),
            'course' => $this->option('course') ?: $this->trans('default_course'),
            'instructor' => $this->option('instructor') ?: $this->trans('default_instructor'),
            'university' => $this->option('university') ?: $this->trans('default_university'),
            'department' => $this->option('department') ?: $this->trans('default_department'),
        ];
    }

    protected function configureDocument(): void
    {
        $this->phpWord->setDefaultFontName('Times New Roman');
        $this->phpWord->setDefaultFontSize(12);
        $this->phpWord->setDefaultParagraphStyle([
            'alignment' => Jc::BOTH,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
            'lineHeight' => 1.5,
        ]);

        $this->phpWord->addParagraphStyle('Normal', [
            'alignment' => Jc::BOTH,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
            'lineHeight' => 1.5,
        ]);

        $this->phpWord->addParagraphStyle('Heading1', [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(12),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addParagraphStyle('Heading2', [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(12),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addParagraphStyle('Heading3', [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addFontStyle('Heading1Font', [
            'name' => 'Times New Roman',
            'size' => 14,
            'bold' => true,
            'allCaps' => true,
        ]);

        $this->phpWord->addFontStyle('Heading2Font', [
            'name' => 'Times New Roman',
            'size' => 13,
            'bold' => true,
        ]);

        $this->phpWord->addFontStyle('Heading3Font', [
            'name' => 'Times New Roman',
            'size' => 12,
            'bold' => true,
        ]);

        $this->phpWord->addParagraphStyle('CoverText', [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(12),
            'spaceAfter' => Converter::pointToTwip(12),
        ]);

        $this->phpWord->addParagraphStyle('CoverTitle', [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(48),
            'spaceAfter' => Converter::pointToTwip(48),
        ]);

        $this->phpWord->addFontStyle('CoverTitleFont', [
            'name' => 'Times New Roman',
            'size' => 16,
            'bold' => true,
            'allCaps' => true,
        ]);

        $this->phpWord->addFontStyle('CoverFont', [
            'name' => 'Times New Roman',
            'size' => 13,
        ]);

        $this->phpWord->addFontStyle('TOCFont', [
            'name' => 'Times New Roman',
            'size' => 12,
        ]);

        $this->phpWord->addParagraphStyle('TOCParagraph', [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addParagraphStyle('Keywords', [
            'alignment' => Jc::BOTH,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addParagraphStyle('FigureCaption', [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addParagraphStyle('TableCaption', [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addFontStyle('FigureCaptionFont', [
            'name' => 'Times New Roman',
            'size' => 11,
            'italic' => true,
        ]);

        $this->phpWord->addFontStyle('TableCaptionFont', [
            'name' => 'Times New Roman',
            'size' => 11,
            'italic' => true,
        ]);

        $this->phpWord->addTitleStyle(1, ['name' => 'Times New Roman', 'size' => 12, 'bold' => true]);
        $this->phpWord->addTitleStyle(2, ['name' => 'Times New Roman', 'size' => 12, 'bold' => true]);
        $this->phpWord->addTitleStyle(3, ['name' => 'Times New Roman', 'size' => 12, 'bold' => true]);
    }

    protected function buildDocument(array $options, ?string $markdownPath): void
    {
        $coverSection = $this->createSection(true);
        $this->renderCoverPage($coverSection, $options);

        $contentSection = $this->createSection();
        $this->addPageNumbers($contentSection);

        if ($markdownPath) {
            $this->addTableOfContents($contentSection);
            $contentSection->addPageBreak();
            $this->resetHeadingCounters();
            $this->addMarkdownContent($contentSection, $markdownPath);
        } else {
            $this->addPrefaceSections($contentSection);
            $contentSection->addPageBreak();
            $this->addTableOfContents($contentSection);
            $contentSection->addPageBreak();
            $this->resetHeadingCounters();
            $this->addPlaceholderChapters($contentSection);
        }
    }

    protected function createSection(bool $isCover = false): Section
    {
        $margin = Converter::cmToTwip(2.54);

        $options = [
            'paperSize' => 'A4',
            'marginTop' => $margin,
            'marginBottom' => $margin,
            'marginLeft' => $margin,
            'marginRight' => $margin,
        ];

        if ($isCover) {
            $options['titlePage'] = true;
        } else {
            $options['pageNumberingStart'] = 1;
        }

        return $this->phpWord->addSection($options);
    }

    protected function addPageNumbers(Section $section): void
    {
        $footer = $section->addFooter();
        $footer->addPreserveText('{PAGE}', ['name' => 'Times New Roman', 'size' => 12], ['alignment' => Jc::CENTER]);
    }

    protected function renderCoverPage(Section $section, array $options): void
    {
        $section->addText(Str::upper($options['university']), 'CoverFont', 'CoverText');
        $section->addText(Str::upper($options['department']), 'CoverFont', 'CoverText');
        $section->addTextBreak(2);
        $section->addText(Str::upper($options['course']), 'CoverFont', 'CoverText');
        $section->addTextBreak(4);
        $section->addText(Str::upper($options['title']), 'CoverTitleFont', 'CoverTitle');
        $section->addTextBreak(6);
        $section->addText($this->trans('student_label') . $options['student'], 'CoverFont', 'CoverText');
        $section->addText($this->trans('student_id_label') . $options['student_id'], 'CoverFont', 'CoverText');
        $section->addText($this->trans('class_label') . $options['class'], 'CoverFont', 'CoverText');
        $section->addText($this->trans('instructor_label') . $options['instructor'], 'CoverFont', 'CoverText');
        $section->addTextBreak(4);
        $section->addText($this->trans('submission_date') . $this->formatSubmissionDate(), 'CoverFont', 'CoverText');
    }

    protected function formatSubmissionDate(): string
    {
        return $this->language === 'en' ? date('F j, Y') : date('d/m/Y');
    }

    protected function addPrefaceSections(Section $section): void
    {
        $this->addHeading($section, $this->trans('acknowledgements'), 1, false);
        $this->addParagraph($section, $this->trans('acknowledgements_placeholder'));
        $section->addPageBreak();

        $this->addHeading($section, $this->trans('abstract'), 1, false);
        $this->addParagraph($section, $this->trans('abstract_placeholder'));
        $section->addText($this->trans('keywords_label') . $this->trans('keywords_placeholder'), null, 'Keywords');
    }

    protected function addTableOfContents(Section $section): void
    {
        $section->addText(Str::upper($this->trans('table_of_contents')), 'Heading1Font', 'Heading1');
        $section->addTOC('TOCFont', 'TOCParagraph', 1, 3);
    }

    protected function resetHeadingCounters(): void
    {
        $this->headingCounters = [1 => 0, 2 => 0, 3 => 0];
    }

    protected function addPlaceholderChapters(Section $section): void
    {
        $chapters = [
            [
                'title' => 'introduction',
                'content' => ['introduction_placeholder'],
                'children' => [
                    ['title' => 'background', 'level' => 2, 'content' => ['background_placeholder']],
                    ['title' => 'problem_statement', 'level' => 2, 'content' => ['problem_placeholder']],
                    ['title' => 'objectives', 'level' => 2, 'content' => ['objectives_placeholder']],
                    ['title' => 'scope', 'level' => 2, 'content' => ['scope_placeholder']],
                    ['title' => 'methodology', 'level' => 2, 'content' => ['methodology_placeholder']],
                ],
            ],
            [
                'title' => 'literature_review',
                'page_break_before' => true,
                'content' => ['literature_placeholder'],
            ],
            [
                'title' => 'requirements_design',
                'page_break_before' => true,
                'content' => ['requirements_placeholder'],
                'children' => [
                    ['title' => 'functional_requirements', 'level' => 2, 'content' => ['functional_placeholder']],
                    ['title' => 'non_functional_requirements', 'level' => 2, 'content' => ['non_functional_placeholder']],
                ],
            ],
            [
                'title' => 'architecture_technology',
                'page_break_before' => true,
                'content' => ['architecture_intro'],
                'children' => [
                    ['title' => 'backend_architecture', 'level' => 2, 'content' => ['backend_placeholder']],
                    ['title' => 'frontend_architecture', 'level' => 2, 'content' => ['frontend_placeholder']],
                ],
            ],
            [
                'title' => 'data_model',
                'page_break_before' => true,
                'content' => ['data_model_intro'],
                'children' => [
                    ['title' => 'database_schema', 'level' => 2, 'content' => ['database_placeholder']],
                ],
            ],
            [
                'title' => 'implementation_features',
                'page_break_before' => true,
                'content' => ['implementation_placeholder'],
                'children' => [
                    ['title' => 'user_management', 'level' => 2, 'content' => ['user_management_placeholder']],
                    ['title' => 'catalog_management', 'level' => 2, 'content' => ['catalog_placeholder']],
                    ['title' => 'order_management', 'level' => 2, 'content' => ['order_placeholder']],
                    ['title' => 'wallet_management', 'level' => 2, 'content' => ['wallet_placeholder']],
                    ['title' => 'review_system', 'level' => 2, 'content' => ['review_placeholder']],
                ],
            ],
            [
                'title' => 'testing_evaluation',
                'page_break_before' => true,
                'content' => ['testing_placeholder'],
                'children' => [
                    ['title' => 'unit_testing', 'level' => 2, 'content' => ['unit_testing_placeholder']],
                    ['title' => 'integration_testing', 'level' => 2, 'content' => ['integration_testing_placeholder']],
                ],
            ],
            [
                'title' => 'discussion',
                'page_break_before' => true,
                'content' => ['discussion_placeholder'],
                'children' => [
                    ['title' => 'limitations', 'level' => 2, 'content' => ['limitations_placeholder']],
                    ['title' => 'future_work', 'level' => 2, 'content' => ['future_work_placeholder']],
                ],
            ],
            [
                'title' => 'conclusion',
                'page_break_before' => true,
                'content' => ['conclusion_placeholder'],
            ],
            [
                'title' => 'references',
                'page_break_before' => true,
                'content' => ['references_placeholder_' . $this->citation],
            ],
            [
                'title' => 'appendices',
                'page_break_before' => true,
                'content' => ['appendices_placeholder'],
                'appendix' => true,
            ],
        ];

        foreach ($chapters as $chapter) {
            $this->renderChapter($section, $chapter);
        }
    }

    protected function renderChapter(Section $section, array $chapter): void
    {
        if (!empty($chapter['page_break_before'])) {
            $section->addPageBreak();
        }

        $level = $chapter['level'] ?? 1;
        $numbered = $chapter['numbered'] ?? true;

        $this->addHeading($section, $this->trans($chapter['title']), $level, $numbered);

        foreach ($chapter['content'] ?? [] as $contentKey) {
            $this->addParagraph($section, $this->trans($contentKey));
        }

        if (!empty($chapter['appendix'])) {
            $this->addParagraph($section, $this->trans('figure_caption_example'), 'FigureCaptionFont', 'FigureCaption');
            $this->addParagraph($section, $this->trans('table_caption_example'), 'TableCaptionFont', 'TableCaption');
        }

        foreach ($chapter['children'] ?? [] as $child) {
            $this->renderChapter($section, $child + ['numbered' => true]);
        }
    }

    protected function addHeading(Section $section, string $text, int $level = 1, bool $numbered = true): void
    {
        $fontStyle = $this->fontStyleForLevel($level);
        $paragraphStyle = $this->paragraphStyleForLevel($level);
        $titleDepth = max(1, min(9, $level));

        if ($numbered) {
            $this->incrementHeadingCounters($level);
            $label = $this->composeHeadingNumber($level);
            $displayText = trim($label . ' ' . ($level === 1 ? Str::upper($text) : $text));
        } else {
            $displayText = $level === 1 ? Str::upper($text) : $text;
        }

        $section->addTitle($displayText, $titleDepth);
        $section->addText($displayText, $fontStyle, $paragraphStyle);
    }

    protected function fontStyleForLevel(int $level): string
    {
        return match ($level) {
            1 => 'Heading1Font',
            2 => 'Heading2Font',
            default => 'Heading3Font',
        };
    }

    protected function paragraphStyleForLevel(int $level): string
    {
        return match ($level) {
            1 => 'Heading1',
            2 => 'Heading2',
            default => 'Heading3',
        };
    }

    protected function incrementHeadingCounters(int $level): void
    {
        if ($level <= 1) {
            $this->headingCounters[1]++;
            $this->headingCounters[2] = 0;
            $this->headingCounters[3] = 0;
        } elseif ($level === 2) {
            if ($this->headingCounters[1] === 0) {
                $this->headingCounters[1] = 1;
            }
            $this->headingCounters[2]++;
            $this->headingCounters[3] = 0;
        } else {
            if ($this->headingCounters[1] === 0) {
                $this->headingCounters[1] = 1;
            }
            if ($this->headingCounters[2] === 0) {
                $this->headingCounters[2] = 1;
            }
            $this->headingCounters[3]++;
        }
    }

    protected function composeHeadingNumber(int $level): string
    {
        if ($level <= 1) {
            return (string) $this->headingCounters[1] . '.';
        }

        if ($level === 2) {
            return $this->headingCounters[1] . '.' . $this->headingCounters[2] . '.';
        }

        return $this->headingCounters[1] . '.' . $this->headingCounters[2] . '.' . $this->headingCounters[3] . '.';
    }

    protected function addParagraph(Section $section, string $text, ?string $fontStyle = null, string $paragraphStyle = 'Normal'): void
    {
        $section->addText($text, $fontStyle, $paragraphStyle);
    }

    protected function addMarkdownContent(Section $section, string $path): void
    {
        $content = file_get_contents($path);
        if ($content === false) {
            return;
        }

        $lines = preg_split('/\r?\n/', $content);
        $buffer = [];

        foreach ($lines as $line) {
            $trimmed = trim($line);

            if ($trimmed === '') {
                $this->flushParagraphBuffer($section, $buffer);
                continue;
            }

            if (preg_match('/^(#{1,6})\s+(.+)$/', $trimmed, $matches)) {
                $this->flushParagraphBuffer($section, $buffer);
                $level = min(strlen($matches[1]), 3);
                $this->addHeading($section, trim($matches[2]), $level, true);
                continue;
            }

            if (preg_match('/^[*-]\s+(.+)$/', $trimmed, $matches)) {
                $this->flushParagraphBuffer($section, $buffer);
                $section->addListItem($matches[1], 0, null, ['spaceBefore' => Converter::pointToTwip(6), 'spaceAfter' => Converter::pointToTwip(6)]);
                continue;
            }

            if (preg_match('/^>\s*(.+)$/', $trimmed, $matches)) {
                $this->flushParagraphBuffer($section, $buffer);
                $section->addText($matches[1], null, [
                    'alignment' => Jc::BOTH,
                    'spaceBefore' => Converter::pointToTwip(6),
                    'spaceAfter' => Converter::pointToTwip(6),
                    'indentation' => ['left' => Converter::cmToTwip(1)],
                ]);
                continue;
            }

            $buffer[] = $trimmed;
        }

        $this->flushParagraphBuffer($section, $buffer);
    }

    protected function flushParagraphBuffer(Section $section, array &$buffer): void
    {
        if (empty($buffer)) {
            return;
        }

        $text = trim(implode(' ', $buffer));
        if ($text !== '') {
            $this->addParagraph($section, $text);
        }

        $buffer = [];
    }

    protected function resolveMarkdownPath(?string $path): ?string
    {
        if (!$path) {
            return null;
        }

        if (file_exists($path)) {
            return $path;
        }

        $candidate = base_path($path);
        return file_exists($candidate) ? $candidate : null;
    }

    protected function getOutputPath(string $title): string
    {
        $custom = $this->option('out');
        if ($custom) {
            $path = Str::startsWith($custom, DIRECTORY_SEPARATOR)
                ? $custom
                : storage_path('app/' . ltrim($custom, '/'));
        } else {
            $slug = Str::slug($title) ?: 'essay';
            $path = storage_path('app/essays/' . $slug . '.docx');
        }

        $directory = dirname($path);
        if (!is_dir($directory)) {
            mkdir($directory, 0755, true);
        }

        return $path;
    }

    protected function loadTranslations(): void
    {
        $vi = [
            'default_title' => 'Hệ thống Thư viện Điện tử',
            'default_student' => 'Nguyễn Văn A',
            'default_class' => 'KTPM2024',
            'default_course' => 'ĐỒ ÁN TỐT NGHIỆP',
            'default_instructor' => 'TS. Nguyễn Văn B',
            'default_university' => 'Trường Đại học ABC',
            'default_department' => 'Khoa Công nghệ Thông tin',
            'student_label' => 'Sinh viên: ',
            'student_id_label' => 'MSSV: ',
            'class_label' => 'Lớp: ',
            'instructor_label' => 'Giảng viên hướng dẫn: ',
            'submission_date' => 'Ngày nộp: ',
            'acknowledgements' => 'Lời cảm ơn',
            'acknowledgements_placeholder' => 'Em xin gửi lời cảm ơn chân thành đến thầy cô, gia đình và bạn bè đã đồng hành, hỗ trợ trong suốt quá trình thực hiện luận văn.',
            'abstract' => 'Tóm tắt',
            'abstract_placeholder' => 'Bản tóm tắt (150-250 từ) mô tả mục tiêu, phương pháp, kết quả chính và đóng góp của đề tài hệ thống thư viện điện tử.',
            'keywords_label' => 'Từ khóa: ',
            'keywords_placeholder' => 'Laravel, Flutter, REST API, thư viện điện tử, quản lý sách',
            'table_of_contents' => 'Mục lục',
            'introduction' => 'Giới thiệu',
            'introduction_placeholder' => 'Chương này trình bày tổng quan đề tài, mục tiêu và cấu trúc luận văn.',
            'background' => 'Bối cảnh',
            'background_placeholder' => 'Bối cảnh chuyển đổi số đặt ra yêu cầu xây dựng hệ thống quản lý sách trực tuyến.',
            'problem_statement' => 'Vấn đề nghiên cứu',
            'problem_placeholder' => 'Các hệ thống thư viện hiện hữu chưa đáp ứng tốt việc mượn, đọc, và quản lý tài liệu số.',
            'objectives' => 'Mục tiêu nghiên cứu',
            'objectives_placeholder' => 'Xây dựng nền tảng thư viện số hỗ trợ đọc giả tiếp cận, mua và quản lý sách điện tử hiệu quả.',
            'scope' => 'Phạm vi nghiên cứu',
            'scope_placeholder' => 'Đề tài tập trung vào chức năng quản lý người dùng, sách, đơn hàng, ví và đánh giá trong khuôn khổ hệ thống sách số.',
            'methodology' => 'Phương pháp nghiên cứu',
            'methodology_placeholder' => 'Áp dụng quy trình Agile/Scrum, phân tích yêu cầu, thiết kế hệ thống và triển khai thử nghiệm.',
            'literature_review' => 'Tổng quan nghiên cứu',
            'literature_placeholder' => 'Tổng hợp các nguồn tài liệu liên quan đến thư viện số, trải nghiệm đọc giả và công nghệ xây dựng hệ thống.',
            'requirements_design' => 'Yêu cầu và thiết kế hệ thống',
            'requirements_placeholder' => 'Phân tích yêu cầu chức năng, phi chức năng và đề xuất kiến trúc tổng thể.',
            'functional_requirements' => 'Yêu cầu chức năng',
            'functional_placeholder' => 'Liệt kê các chức năng như đăng ký, đăng nhập, quản lý sách, đơn hàng, ví và đánh giá.',
            'non_functional_requirements' => 'Yêu cầu phi chức năng',
            'non_functional_placeholder' => 'Yêu cầu về hiệu năng, bảo mật, tính sẵn sàng, khả năng mở rộng và trải nghiệm người dùng.',
            'architecture_technology' => 'Kiến trúc và công nghệ',
            'architecture_intro' => 'Mô tả kiến trúc hai lớp client-server và các thành phần triển khai.',
            'backend_architecture' => 'Kiến trúc Backend',
            'backend_placeholder' => 'Sử dụng Laravel 12 (PHP 8.2) kết hợp Sanctum, REST API, Eloquent ORM, Vite và PHPUnit.',
            'frontend_architecture' => 'Kiến trúc Frontend',
            'frontend_placeholder' => 'Xây dựng ứng dụng Flutter 3 (Material 3) đa nền tảng với các service quản lý trạng thái và HTTP/dio.',
            'data_model' => 'Mô hình dữ liệu',
            'data_model_intro' => 'Giới thiệu cấu trúc cơ sở dữ liệu và mối liên hệ giữa các bảng chính.',
            'database_schema' => 'Sơ đồ cơ sở dữ liệu',
            'database_placeholder' => 'Các thực thể users, authors, categories, books, orders, wallets, reviews, review_votes cùng quan hệ liên kết.',
            'implementation_features' => 'Cài đặt và tính năng',
            'implementation_placeholder' => 'Trình bày cách triển khai từng module và tương tác người dùng.',
            'user_management' => 'Quản lý người dùng',
            'user_management_placeholder' => 'Đăng ký, đăng nhập, cập nhật hồ sơ, phân quyền và quản lý thư viện cá nhân.',
            'catalog_management' => 'Quản lý danh mục sách',
            'catalog_placeholder' => 'CRUD sách, tác giả, danh mục và tải lên tệp PDF.',
            'order_management' => 'Quản lý đơn hàng',
            'order_placeholder' => 'Tạo đơn, thanh toán, hủy và theo dõi lịch sử đơn hàng.',
            'wallet_management' => 'Quản lý ví',
            'wallet_placeholder' => 'Chức năng nạp tiền, theo dõi số dư, phê duyệt yêu cầu nạp và điều chỉnh.',
            'review_system' => 'Hệ thống đánh giá',
            'review_placeholder' => 'Người dùng viết đánh giá, bình luận, vote và quản lý phản hồi.',
            'testing_evaluation' => 'Kiểm thử và đánh giá',
            'testing_placeholder' => 'Mô tả chiến lược kiểm thử, công cụ sử dụng và tiêu chí đánh giá.',
            'unit_testing' => 'Kiểm thử đơn vị',
            'unit_testing_placeholder' => 'Xây dựng test PHPUnit/Pest cho các lớp dịch vụ và API.',
            'integration_testing' => 'Kiểm thử tích hợp',
            'integration_testing_placeholder' => 'Kiểm thử luồng đặt sách, thanh toán và đồng bộ dữ liệu giữa các module.',
            'discussion' => 'Thảo luận',
            'discussion_placeholder' => 'Đánh giá kết quả đạt được, các điểm mạnh và hạn chế của hệ thống.',
            'limitations' => 'Hạn chế',
            'limitations_placeholder' => 'Nêu rõ hạn chế về dữ liệu mẫu, hiệu năng và trải nghiệm người dùng.',
            'future_work' => 'Hướng phát triển',
            'future_work_placeholder' => 'Đề xuất các tính năng và cải tiến cho các phiên bản tiếp theo.',
            'conclusion' => 'Kết luận',
            'conclusion_placeholder' => 'Tổng kết đóng góp chính, bài học kinh nghiệm và khả năng ứng dụng.',
            'references' => 'Tài liệu tham khảo',
            'references_placeholder_apa' => 'Liệt kê tài liệu theo chuẩn APA: tác giả, năm, tiêu đề, nhà xuất bản/URL.',
            'references_placeholder_ieee' => 'Liệt kê tài liệu theo chuẩn IEEE: [số thứ tự] Tên tác giả, "Tiêu đề", Nguồn, Năm.',
            'appendices' => 'Phụ lục',
            'appendices_placeholder' => 'Chèn các sơ đồ, bảng biểu, hình ảnh minh họa và tài liệu bổ sung.',
            'figure_caption_example' => 'Hình 1.1: Ví dụ chú thích hình (sử dụng style FigureCaption).',
            'table_caption_example' => 'Bảng 1.1: Ví dụ chú thích bảng (sử dụng style TableCaption).',
            'success_message' => 'Đã tạo tài liệu essay thành công!',
        ];

        $en = [
            'default_title' => 'Digital Bookstore System',
            'default_student' => 'John Doe',
            'default_class' => 'CS2024',
            'default_course' => 'GRADUATION THESIS',
            'default_instructor' => 'Dr. Jane Smith',
            'default_university' => 'ABC University',
            'default_department' => 'Department of Computer Science',
            'student_label' => 'Student: ',
            'student_id_label' => 'Student ID: ',
            'class_label' => 'Class: ',
            'instructor_label' => 'Advisor: ',
            'submission_date' => 'Submission Date: ',
            'acknowledgements' => 'Acknowledgements',
            'acknowledgements_placeholder' => 'I would like to extend my sincere thanks to my advisor, family, and colleagues for their guidance throughout this project.',
            'abstract' => 'Abstract',
            'abstract_placeholder' => 'Provide a 150-250 word summary covering objectives, methodology, findings, and contributions of the digital bookstore system.',
            'keywords_label' => 'Keywords: ',
            'keywords_placeholder' => 'Laravel, Flutter, REST API, digital bookstore, book management',
            'table_of_contents' => 'Table of Contents',
            'introduction' => 'Introduction',
            'introduction_placeholder' => 'This chapter introduces the context, objectives, and structure of the thesis.',
            'background' => 'Background',
            'background_placeholder' => 'Digital transformation demands an online bookstore platform for readers and publishers.',
            'problem_statement' => 'Problem Statement',
            'problem_placeholder' => 'Existing systems do not streamline purchasing, reading, and managing digital titles effectively.',
            'objectives' => 'Objectives',
            'objectives_placeholder' => 'Design and implement a digital bookstore platform enabling readers to discover, purchase, and manage e-books.',
            'scope' => 'Scope',
            'scope_placeholder' => 'The thesis focuses on user, catalog, order, wallet, and review management features.',
            'methodology' => 'Methodology',
            'methodology_placeholder' => 'Adopts Agile/Scrum development, requirement analysis, architectural design, and iterative implementation.',
            'literature_review' => 'Literature Review',
            'literature_placeholder' => 'Survey prior work on digital libraries, reader engagement, and supporting technologies.',
            'requirements_design' => 'Requirements & System Design',
            'requirements_placeholder' => 'Detail functional/non-functional requirements and propose the target architecture.',
            'functional_requirements' => 'Functional Requirements',
            'functional_placeholder' => 'Identify capabilities such as sign-up, authentication, catalog management, ordering, wallets, and reviews.',
            'non_functional_requirements' => 'Non-functional Requirements',
            'non_functional_placeholder' => 'Define expectations for performance, security, availability, scalability, and UX.',
            'architecture_technology' => 'Architecture & Technology',
            'architecture_intro' => 'Describe the overall architecture, deployment view, and technology stack.',
            'backend_architecture' => 'Backend Architecture',
            'backend_placeholder' => 'Laravel 12 (PHP 8.2) with Sanctum authentication, RESTful services, Eloquent ORM, Vite, and PHPUnit.',
            'frontend_architecture' => 'Frontend Architecture',
            'frontend_placeholder' => 'Flutter 3 with Material Design 3, multi-platform support, and service-driven state/data layers.',
            'data_model' => 'Data Model',
            'data_model_intro' => 'Outline the database schema and entity relationships.',
            'database_schema' => 'Database Schema',
            'database_placeholder' => 'Entities include users, authors, categories, books, orders, wallets, reviews, and review_votes.',
            'implementation_features' => 'Implementation & Features',
            'implementation_placeholder' => 'Explain how each module is implemented and integrated.',
            'user_management' => 'User Management',
            'user_management_placeholder' => 'Covers registration, authentication, profile maintenance, and personal library tracking.',
            'catalog_management' => 'Catalog Management',
            'catalog_placeholder' => 'Administrative CRUD for titles, authors, categories, and PDF ingestion.',
            'order_management' => 'Order Management',
            'order_placeholder' => 'Order creation, payment handling, cancellation, and history tracking.',
            'wallet_management' => 'Wallet Management',
            'wallet_placeholder' => 'Supports balance tracking, top-up requests, approvals, and adjustments.',
            'review_system' => 'Review System',
            'review_placeholder' => 'Readers can submit reviews, comments, and vote on feedback.',
            'testing_evaluation' => 'Testing & Evaluation',
            'testing_placeholder' => 'Summarize testing strategy, tooling, and assessment criteria.',
            'unit_testing' => 'Unit Testing',
            'unit_testing_placeholder' => 'Implement PHPUnit/Pest tests for services, controllers, and REST endpoints.',
            'integration_testing' => 'Integration Testing',
            'integration_testing_placeholder' => 'Test end-to-end flows for purchasing, payment, and data synchronization.',
            'discussion' => 'Discussion',
            'discussion_placeholder' => 'Discuss achievements, trade-offs, and experiential insights.',
            'limitations' => 'Limitations',
            'limitations_placeholder' => 'Highlight dataset, scalability, or UX limitations requiring attention.',
            'future_work' => 'Future Work',
            'future_work_placeholder' => 'Recommend future enhancements and extension opportunities.',
            'conclusion' => 'Conclusion',
            'conclusion_placeholder' => 'Summarize key contributions, lessons learned, and potential impact.',
            'references' => 'References',
            'references_placeholder_apa' => 'Document references in APA format: author, year, title, publisher/URL.',
            'references_placeholder_ieee' => 'Document references in IEEE format: [index] Author, "Title", Source, Year.',
            'appendices' => 'Appendices',
            'appendices_placeholder' => 'Include supplementary figures, tables, and supporting assets.',
            'figure_caption_example' => 'Figure 1.1: Sample figure caption (use the FigureCaption style).',
            'table_caption_example' => 'Table 1.1: Sample table caption (use the TableCaption style).',
            'success_message' => 'Essay document generated successfully!',
        ];

        $this->translations = $this->language === 'vi' ? $vi : $en;
    }

    protected function trans(string $key): string
    {
        return $this->translations[$key] ?? $key;
    }
}
