<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Str;
use PhpOffice\PhpWord\Element\Section;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\PhpWord;
use PhpOffice\PhpWord\Settings;
use PhpOffice\PhpWord\Shared\Converter;
use PhpOffice\PhpWord\SimpleType\Jc;

class GenerateEssayPdfExtraction extends Command
{
    protected $signature = 'essay:generate-pdf-extraction
        {--student=Nguyễn Văn A : Tên sinh viên}
        {--student-id=20210001 : Mã số sinh viên}
        {--class=CNTT-K64 : Lớp học}
        {--instructor=TS. Nguyễn Văn B : Tên giảng viên hướng dẫn}
        {--university=TRƯỜNG ĐẠI HỌC CÔNG NGHỆ : Tên trường đại học}
        {--department=KHOA CÔNG NGHỆ THÔNG TIN : Tên khoa}
        {--output=storage/app/essays/pdf_text_extraction_essay.docx : Đường dẫn tệp đầu ra}';

    protected $description = 'Tạo bài tiểu luận học thuật về công nghệ trích xuất văn bản từ PDF ở định dạng .docx.';

    protected PhpWord $phpWord;

    protected array $headingCounters = [1 => 0, 2 => 0, 3 => 0];

    public function handle(): int
    {
        $options = $this->resolveOptions();

        $this->phpWord = new PhpWord();
        $this->configureDocument();

        $coverSection = $this->createSection(true, false);
        $this->renderCoverPage($coverSection, $options);

        $frontMatterSection = $this->createSection(false, false);
        $this->addAcknowledgements($frontMatterSection);
        $frontMatterSection->addPageBreak();
        $this->addAbstract($frontMatterSection);
        $frontMatterSection->addPageBreak();
        $this->addTableOfContents($frontMatterSection);

        $mainSection = $this->createSection(false, true);
        $this->addPageNumbers($mainSection);
        $this->resetHeadingCounters();
        $this->renderChapters($mainSection);
        $this->renderReferences($mainSection);
        $this->renderAppendices($mainSection);

        $outputPath = $this->storeDocument($options['output']);

        $this->info('Đã tạo bài tiểu luận về PDF text extraction thành công.');
        $this->line($outputPath);

        return Command::SUCCESS;
    }

    protected function resolveOptions(): array
    {
        return [
            'student' => $this->option('student'),
            'student_id' => $this->option('student-id'),
            'class' => $this->option('class'),
            'instructor' => $this->option('instructor'),
            'university' => $this->option('university'),
            'department' => $this->option('department'),
            'output' => $this->option('output'),
        ];
    }

    protected function configureDocument(): void
    {
        $this->phpWord->setDefaultFontName('Times New Roman');
        Settings::setOutputEscapingEnabled(true);

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

        $this->phpWord->addTitleStyle(1, [
            'name' => 'Times New Roman',
            'size' => 14,
            'bold' => true,
            'allCaps' => true,
        ], [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(12),
            'spaceAfter' => Converter::pointToTwip(12),
        ]);

        $this->phpWord->addTitleStyle(2, [
            'name' => 'Times New Roman',
            'size' => 13,
            'bold' => true,
        ], [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(12),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addTitleStyle(3, [
            'name' => 'Times New Roman',
            'size' => 12,
            'bold' => true,
        ], [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addParagraphStyle('CoverCentered', [
            'alignment' => Jc::CENTER,
            'spaceBefore' => Converter::pointToTwip(12),
            'spaceAfter' => Converter::pointToTwip(12),
        ]);

        $this->phpWord->addFontStyle('CoverTitleFont', [
            'name' => 'Times New Roman',
            'size' => 18,
            'bold' => true,
            'allCaps' => true,
        ]);

        $this->phpWord->addFontStyle('CoverSubtitleFont', [
            'name' => 'Times New Roman',
            'size' => 14,
            'bold' => true,
        ]);

        $this->phpWord->addFontStyle('CoverBodyFont', [
            'name' => 'Times New Roman',
            'size' => 13,
        ]);

        $this->phpWord->addParagraphStyle('TOCParagraph', [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
        ]);

        $this->phpWord->addFontStyle('TOCFont', [
            'name' => 'Times New Roman',
            'size' => 12,
        ]);

        $this->phpWord->addFontStyle('CodeFont', [
            'name' => 'Courier New',
            'size' => 10,
        ]);

        $this->phpWord->addParagraphStyle('CodeParagraph', [
            'alignment' => Jc::START,
            'spaceBefore' => Converter::pointToTwip(6),
            'spaceAfter' => Converter::pointToTwip(6),
            'indentation' => ['left' => Converter::cmToTwip(1)],
        ]);
    }

    protected function createSection(bool $isCover, bool $withNumbering): Section
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
        }

        if ($withNumbering) {
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
        $section->addText(Str::upper($options['university']), 'CoverBodyFont', 'CoverCentered');
        $section->addText(Str::upper($options['department']), 'CoverBodyFont', 'CoverCentered');
        $section->addTextBreak(2);
        $section->addText('BÀI TIỂU LUẬN MÔN HỌC', 'CoverSubtitleFont', 'CoverCentered');
        $section->addTextBreak(3);
        $section->addText('CÔNG NGHỆ TRÍCH XUẤT VĂN BẢN TỪ PDF', 'CoverTitleFont', 'CoverCentered');
        $section->addText('VÀ ỨNG DỤNG TRONG HỆ THỐNG HIỆU SÁCH ĐIỆN TỬ', 'CoverTitleFont', 'CoverCentered');
        $section->addTextBreak(1);
        $section->addText('PDF Text Extraction Technology & Application in Digital Bookstore', 'CoverSubtitleFont', 'CoverCentered');
        $section->addTextBreak(4);
        $section->addText('Sinh viên thực hiện: ' . $options['student'], 'CoverBodyFont', 'CoverCentered');
        $section->addText('Mã số sinh viên: ' . $options['student_id'], 'CoverBodyFont', 'CoverCentered');
        $section->addText('Lớp: ' . $options['class'], 'CoverBodyFont', 'CoverCentered');
        $section->addText('Giảng viên hướng dẫn: ' . $options['instructor'], 'CoverBodyFont', 'CoverCentered');
        $section->addTextBreak(3);
        $section->addText('Ngày nộp: ' . $this->formatSubmissionDate(), 'CoverBodyFont', 'CoverCentered');
    }

    protected function formatSubmissionDate(): string
    {
        return now()->format('d/m/Y');
    }

    protected function addAcknowledgements(Section $section): void
    {
        $this->addHeading($section, 'Lời cảm ơn', 1, false);

        foreach ($this->acknowledgementParagraphs() as $paragraph) {
            $this->addParagraph($section, $paragraph);
        }
    }

    protected function addAbstract(Section $section): void
    {
        $this->addHeading($section, 'Tóm tắt', 1, false);

        foreach ($this->abstractParagraphs() as $paragraph) {
            $this->addParagraph($section, $paragraph);
        }

        $section->addText('Từ khóa: PDF, text extraction, parsing, smalot/pdfparser, Laravel, Flutter, digital bookstore, page selection, input validation', null, 'Normal');
    }

    protected function addTableOfContents(Section $section): void
    {
        $this->addHeading($section, 'Mục lục', 1, false);
        $section->addTOC('TOCFont', 'TOCParagraph', 1, 3);
    }

    protected function resetHeadingCounters(): void
    {
        $this->headingCounters = [1 => 0, 2 => 0, 3 => 0];
    }

    protected function renderChapters(Section $section): void
    {
        $this->renderNodes($section, $this->chapters());
    }

    protected function renderReferences(Section $section): void
    {
        $section->addPageBreak();
        $this->addHeading($section, 'Tài liệu tham khảo', 1, false);

        foreach ($this->references() as $reference) {
            $this->addParagraph($section, $reference);
        }
    }

    protected function renderAppendices(Section $section): void
    {
        $section->addPageBreak();
        $this->addHeading($section, 'Phụ lục', 1, false);
        $this->renderAppendixContent($section);
    }

    protected function addHeading(Section $section, string $text, int $level, bool $numbered = true): void
    {
        if ($numbered) {
            $this->incrementHeadingCounters($level);
            $number = $this->composeHeadingNumber($level);

            if ($level === 1) {
                $displayText = 'CHƯƠNG ' . $number . ': ' . Str::upper($text);
            } else {
                $displayText = $number . ' ' . $text;
            }
        } else {
            $displayText = $level === 1 ? Str::upper($text) : $text;
        }

        $section->addTitle($displayText, min($level, 9));
    }

    protected function incrementHeadingCounters(int $level): void
    {
        if ($level === 1) {
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
        $parts = [$this->headingCounters[1]];

        if ($level >= 2) {
            $parts[] = $this->headingCounters[2];
        }

        if ($level >= 3) {
            $parts[] = $this->headingCounters[3];
        }

        return implode('.', $parts);
    }

    protected function addParagraph(Section $section, string $text): void
    {
        $section->addText($text, null, 'Normal');
    }

    protected function addCodeBlock(Section $section, string $code): void
    {
        $lines = explode("\n", $code);
        foreach ($lines as $line) {
            $section->addText($line, 'CodeFont', 'CodeParagraph');
        }
    }

    protected function renderNodes(Section $section, array $nodes): void
    {
        foreach ($nodes as $node) {
            if (!empty($node['page_break'])) {
                $section->addPageBreak();
            }

            $level = $node['level'] ?? 1;
            $numbered = $node['numbered'] ?? true;

            $this->addHeading($section, $node['title'], $level, $numbered);

            foreach ($node['paragraphs'] ?? [] as $paragraph) {
                $this->addParagraph($section, $paragraph);
            }

            if (!empty($node['lists'])) {
                foreach ($node['lists'] as $list) {
                    foreach ($list as $item) {
                        $section->addListItem($item, 0, null, [
                            'spaceBefore' => Converter::pointToTwip(3),
                            'spaceAfter' => Converter::pointToTwip(3),
                        ]);
                    }
                }
            }

            if (!empty($node['code'])) {
                $this->addCodeBlock($section, $node['code']);
            }

            if (!empty($node['children'])) {
                $this->renderNodes($section, $node['children']);
            }
        }
    }

    protected function storeDocument(string $output): string
    {
        $path = Str::startsWith($output, DIRECTORY_SEPARATOR)
            ? $output
            : base_path($output);

        $directory = dirname($path);

        if (!is_dir($directory)) {
            mkdir($directory, 0755, true);
        }

        IOFactory::createWriter($this->phpWord, 'Word2007')->save($path);

        return realpath($path) ?: $path;
    }

    protected function acknowledgementParagraphs(): array
    {
        return [
            'Lời đầu tiên, em xin gửi lời cảm ơn sâu sắc đến quý Thầy Cô trong Khoa Công nghệ Thông tin đã tận tình truyền đạt kiến thức, tạo nền tảng vững chắc giúp em hoàn thành đề tài này. Đặc biệt, em xin chân thành cảm ơn giảng viên hướng dẫn đã dành thời gian chỉ bảo, góp ý và định hướng em trong suốt quá trình nghiên cứu công nghệ trích xuất văn bản từ PDF và ứng dụng vào hệ thống thực tế.',
            'Em xin cảm ơn gia đình, người thân đã luôn động viên, khích lệ và tạo điều kiện tốt nhất để em có thể tập trung nghiên cứu và hoàn thành bài tiểu luận. Sự quan tâm và ủng hộ của gia đình là nguồn động lực to lớn giúp em vượt qua những khó khăn trong quá trình thực hiện.',
            'Em cũng xin gửi lời cảm ơn đến cộng đồng mã nguồn mở, đặc biệt là tác giả thư viện smalot/pdfparser và các đóng góp viên, những người đã phát triển và duy trì công cụ mạnh mẽ này, tạo điều kiện cho các nhà phát triển như em có thể xây dựng các giải pháp xử lý PDF hiệu quả.',
            'Cuối cùng, em xin trân trọng cảm ơn tất cả những người đã đóng góp, giúp đỡ em hoàn thành bài tiểu luận này. Dù đã cố gắng hết sức, nhưng do thời gian và năng lực có hạn, bài tiểu luận không tránh khỏi những thiếu sót. Em rất mong nhận được sự góp ý, chỉ bảo của Quý Thầy Cô và các bạn để bài tiểu luận được hoàn thiện hơn.',
        ];
    }

    protected function abstractParagraphs(): array
    {
        return [
            'PDF (Portable Document Format) là định dạng tài liệu số phổ biến nhất hiện nay, được sử dụng rộng rãi trong xuất bản sách điện tử, tài liệu học thuật và lưu trữ dữ liệu. Nhu cầu trích xuất văn bản từ PDF ngày càng tăng cao để phục vụ các mục đích như tìm kiếm toàn văn, phân tích dữ liệu, dịch thuật tự động, và nâng cao khả năng tiếp cận cho người khiếm thị thông qua công nghệ text-to-speech. Tuy nhiên, việc trích xuất văn bản từ PDF không phải là tầm thường do cấu trúc phức tạp của định dạng này, nơi văn bản không được lưu trữ theo thứ tự đọc tự nhiên mà dựa trên các lệnh vẽ và tọa độ trên trang.',
            'Bài tiểu luận này trình bày quá trình nghiên cứu công nghệ trích xuất văn bản từ PDF và triển khai tính năng này vào hệ thống Hiệu sách điện tử My Digital Bookstore. Nghiên cứu bắt đầu bằng việc phân tích cấu trúc file PDF theo tiêu chuẩn ISO 32000, bao gồm cách PDF lưu trữ văn bản thông qua các operators (Tj, TJ, Td, Tm), hệ thống fonts và encoding, cũng như content streams của từng trang. Sau đó, bài tiểu luận khảo sát các phương pháp trích xuất văn bản khác nhau: text parsing (phân tích cú pháp), OCR (nhận dạng ký tự quang học) và hybrid approach, cùng với so sánh các thư viện phổ biến như smalot/pdfparser (PHP), Apache PDFBox (Java) và pdfminer.six (Python).',
            'Hệ thống được triển khai với backend Laravel 12 sử dụng thư viện smalot/pdfparser để parse PDF và trích xuất text theo page selection do người dùng chỉ định. API endpoint POST /api/books/{book}/extract-text được bảo mật bằng Laravel Sanctum và hỗ trợ cú pháp page selection linh hoạt như "1,5,10,30-40,100-200". Service layer PdfTextExtractor thực hiện input sanitization nghiêm ngặt với regex validation, range validation và DoS prevention (giới hạn tối đa 1000 trang mỗi request). Frontend Flutter cung cấp UI trực quan với page selection dialog và text viewer screen, cho phép người dùng xem, copy và lưu văn bản đã trích xuất.',
            'Kết quả kiểm thử cho thấy hệ thống hoạt động hiệu quả với các PDF thông thường, đạt performance dưới 5 giây cho 100 trang và xử lý đúng đắn các edge cases như input không hợp lệ, out-of-bounds pages, và corrupted PDFs. Tính năng này mang lại giá trị thực tiễn cao cho người dùng hiệu sách điện tử, đồng thời tạo nền tảng cho các chức năng nâng cao trong tương lai như full-text search, AI summarization và text-to-speech integration. Bài tiểu luận cũng thảo luận các hạn chế hiện tại (không hỗ trợ OCR, complex layouts, custom fonts) và đề xuất hướng phát triển trong ngắn, trung và dài hạn.',
        ];
    }

    protected function chapters(): array
    {
        return [
            [
                'title' => 'Giới thiệu',
                'level' => 1,
                'page_break' => true,
                'paragraphs' => [
                    'Chương này cung cấp cái nhìn tổng quan về công nghệ PDF và vai trò của việc trích xuất văn bản trong hệ thống hiệu sách điện tử hiện đại. Với sự phổ biến của PDF như một định dạng chuẩn cho tài liệu số và sách điện tử, nhu cầu trích xuất và xử lý văn bản từ PDF trở thành yêu cầu thiết yếu để nâng cao trải nghiệm người dùng và mở rộng khả năng ứng dụng.',
                ],
                'children' => [
                    [
                        'title' => 'Bối cảnh',
                        'level' => 2,
                        'paragraphs' => [
                            'PDF (Portable Document Format) là định dạng tài liệu số được phát triển bởi Adobe Systems vào năm 1993 và đã trở thành tiêu chuẩn quốc tế ISO 32000 từ năm 2008. Định dạng này được thiết kế với mục tiêu chính là bảo toàn hoàn chỉnh định dạng trình bày của tài liệu (layout, fonts, images, colors) trên mọi nền tảng và thiết bị khác nhau, độc lập với phần mềm, phần cứng hay hệ điều hành được sử dụng để tạo hoặc xem tài liệu.',
                            'Trong ngành xuất bản sách điện tử, PDF chiếm vị trí thống trị nhờ các ưu điểm vượt trội: khả năng bảo toàn format chính xác, hỗ trợ fonts embedded đảm bảo hiển thị nhất quán, tích hợp được images và graphics chất lượng cao, bảo mật thông qua encryption và digital signatures, và kích thước file được tối ưu hóa. Các nền tảng hiệu sách điện tử lớn như Amazon Kindle, Google Play Books và Apple Books đều hỗ trợ PDF song song với các định dạng riêng (AZW, EPUB) để đáp ứng nhu cầu đa dạng của người dùng.',
                            'Tuy nhiên, PDF được thiết kế chủ yếu cho mục đích presentation (trình bày) chứ không phải data extraction (trích xuất dữ liệu). Điều này tạo ra thách thức khi cần xử lý nội dung văn bản của PDF cho các mục đích như tìm kiếm toàn văn, phân tích ngữ nghĩa, dịch thuật tự động, text-to-speech, hoặc đơn giản là copy-paste một đoạn văn bản. Văn bản trong PDF không được lưu theo thứ tự đọc tự nhiên mà được định vị bằng tọa độ và các lệnh vẽ, fonts có thể sử dụng custom encoding, và layout phức tạp (multiple columns, tables) làm khó khăn việc reconstruct reading order.',
                        ],
                    ],
                    [
                        'title' => 'Vấn đề nghiên cứu',
                        'level' => 2,
                        'paragraphs' => [
                            'Trong bối cảnh hệ thống Hiệu sách điện tử My Digital Bookstore, nhu cầu trích xuất văn bản từ PDF được xác định qua nhiều use cases thực tế của người dùng. Sinh viên và nhà nghiên cứu cần extract quotes từ textbooks và academic papers để viết luận văn, làm bài tập. Người đọc muốn copy đoạn văn bản để tra cứu từ điển, dịch sang ngôn ngữ khác, hoặc ghi chú lại. Người khiếm thị cần chuyển đổi text sang speech để "đọc" sách. Ngoài ra, khả năng trích xuất text là nền tảng cho các tính năng nâng cao như full-text search trong thư viện cá nhân, automatic summarization bằng AI, và content analysis.',
                            'Tuy nhiên, việc triển khai tính năng này gặp phải nhiều thách thức kỹ thuật. Thứ nhất, như đã đề cập, PDF không lưu text theo reading order mà theo drawing order dựa trên tọa độ, đòi hỏi phải reconstruct thứ tự đọc từ positioning information. Thứ hai, fonts và encoding rất đa dạng: Type 1, TrueType, Type 3, CIDFont với các encoding schemes khác nhau (WinAnsiEncoding, MacRomanEncoding, custom encoding, Unicode với ToUnicode CMap), dẫn đến khó khăn trong việc map glyph IDs sang Unicode codepoints. Thứ ba, layout phức tạp như multiple columns, tables, footnotes, headers/footers khiến việc xác định reading order trở nên phức tạp hơn. Thứ tư, một số PDF là image-based (scanned documents) không có text layer, cần sử dụng OCR. Cuối cùng, corrupted hoặc malformed PDFs có thể gây lỗi khi parsing.',
                            'Bên cạnh thách thức kỹ thuật, các vấn đề về security cũng cần được quan tâm. Input từ người dùng (page selection) phải được sanitize và validate nghiêm ngặt để tránh injection attacks. DoS prevention cần được triển khai để ngăn chặn user yêu cầu extract quá nhiều trang hoặc file quá lớn, làm quá tải server. Rate limiting là cần thiết để ngăn abuse. Và việc xác thực quyền truy cập PDF (user có quyền đọc book này không) phải được enforce đúng cách.',
                        ],
                    ],
                    [
                        'title' => 'Mục tiêu',
                        'level' => 2,
                        'paragraphs' => [
                            'Mục tiêu chính của nghiên cứu này là thiết kế và triển khai một hệ thống trích xuất văn bản từ PDF hoàn chỉnh, bảo mật và hiệu quả, được tích hợp vào ứng dụng My Digital Bookstore. Các mục tiêu cụ thể bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Nghiên cứu cấu trúc file PDF theo tiêu chuẩn ISO 32000, hiểu rõ cách PDF lưu trữ và tổ chức văn bản thông qua objects, content streams, operators và fonts.',
                                'Khảo sát và so sánh các phương pháp trích xuất văn bản: text parsing, OCR, và hybrid approaches, để xác định phương pháp phù hợp nhất với yêu cầu của hệ thống.',
                                'Đánh giá các thư viện PDF processing phổ biến trong các ngôn ngữ khác nhau (PHP, Java, Python) về tính năng, performance, ease of use và licensing, từ đó lựa chọn thư viện tối ưu cho Laravel backend.',
                                'Thiết kế RESTful API endpoint cho PDF text extraction với input sanitization, authentication, authorization và rate limiting đầy đủ.',
                                'Triển khai service layer với business logic xử lý page selection parsing, validation, và text extraction từ PDF documents.',
                                'Phát triển Flutter UI cho phép người dùng chọn trang cần extract (individual pages hoặc ranges), view extracted text, copy to clipboard, save to file và share.',
                                'Xây dựng comprehensive test suite bao gồm unit tests, feature tests và integration tests để đảm bảo chất lượng và độ tin cậy.',
                                'Đánh giá performance của hệ thống với các PDF có kích thước và độ phức tạp khác nhau, xác định bottlenecks và tối ưu hóa.',
                                'Kiểm thử tính chính xác của extraction với various PDF types: simple text, multiple columns, custom fonts, complex layouts.',
                                'Tài liệu hóa toàn bộ quá trình từ lý thuyết đến triển khai, tạo foundation cho future enhancements như OCR integration, full-text search, và AI-powered features.',
                            ],
                        ],
                    ],
                    [
                        'title' => 'Phạm vi',
                        'level' => 2,
                        'paragraphs' => [
                            'Nghiên cứu này tập trung vào trích xuất văn bản từ PDF có text layer (text-based PDF), không bao gồm OCR cho image-based PDF. Phạm vi triển khai cụ thể:',
                        ],
                        'lists' => [
                            [
                                'Backend implementation: Sử dụng PHP 8.2 với Laravel Framework 12, thư viện smalot/pdfparser cho PDF parsing, Laravel Sanctum cho authentication.',
                                'Frontend implementation: Flutter 3 framework với Material Design 3, singleton service pattern, responsive UI cho mobile, web và desktop.',
                                'Page selection syntax: Hỗ trợ comma-separated individual pages ("1,5,10"), ranges ("30-40"), và combined ("1,5,10,30-40,100-200"). Empty input nghĩa là extract all pages.',
                                'Input validation: Sanitization với whitespace removal, regex validation cho format, range validation (start ≤ end), bounds checking (page ≤ total_pages), duplicate removal, và DoS prevention (max 1000 pages per request).',
                                'Security measures: Sanctum token authentication, authorization check (user owns book hoặc book is public), input sanitization, rate limiting (10 requests per minute per user), error handling với user-friendly messages.',
                                'Output format: Plain text, preserving paragraphs và line breaks (best effort), Unicode support.',
                                'UI features: Page selection dialog với radio buttons (all pages / specific pages), text input field với validation, extracted text viewer với selectable text, copy to clipboard button, save to file button (platform-specific), metadata display (total pages, extracted pages, page count).',
                            ],
                        ],
                        'paragraphs' => [
                            'Các tính năng không nằm trong phạm vi bao gồm: OCR cho scanned PDFs, preserve formatting (bold, italic, font sizes), table structure extraction, image extraction, hyperlink extraction, annotation và form data extraction, multi-threading hoặc async processing cho large files, caching extracted text, export to multiple formats (HTML, Markdown, JSON).',
                        ],
                    ],
                    [
                        'title' => 'Phương pháp tiếp cận',
                        'level' => 2,
                        'paragraphs' => [
                            'Nghiên cứu được thực hiện theo phương pháp tiếp cận hệ thống, kết hợp giữa nghiên cứu lý thuyết và triển khai thực tiễn:',
                        ],
                        'lists' => [
                            [
                                'Giai đoạn 1 - Nghiên cứu lý thuyết: Đọc PDF Reference Specification (ISO 32000), nghiên cứu về PDF structure (header, body, xref table, trailer), hiểu text representation trong PDF (operators, positioning, fonts, encoding), phân tích các text extraction techniques và trade-offs của từng approach.',
                                'Giai đoạn 2 - Khảo sát công cụ: So sánh các thư viện PDF processing: smalot/pdfparser (PHP), Apache PDFBox (Java), pdfminer.six (Python), PyPDF2 (Python), TCPDF (PHP), đánh giá theo các tiêu chí features, performance, ease of integration, documentation quality, community support, licensing.',
                                'Giai đoạn 3 - Thiết kế hệ thống: Thiết kế API endpoint với request/response schema, thiết kế service layer architecture với separation of concerns (parsing, validation, extraction), thiết kế error handling strategy với specific error codes và messages, thiết kế security measures (authentication, authorization, input sanitization, rate limiting), thiết kế UI/UX flow cho page selection và text viewing.',
                                'Giai đoạn 4 - Triển khai backend: Cài đặt smalot/pdfparser thông qua Composer, tạo PdfTextExtractor service với methods: parsePageSelection(), validatePageNumber(), validateRange(), extractText(), register service trong AppServiceProvider, tạo API controller với endpoint handler, implement authentication và authorization middleware, implement rate limiting, write comprehensive error handling, log errors for debugging.',
                                'Giai đoạn 5 - Triển khai frontend: Tạo PdfTextService singleton, implement PageSelectionDialog widget với radio buttons và text input, implement real-time validation trong text input, implement TextViewerScreen với selectable text widget, implement copy to clipboard functionality, implement save to file functionality (platform-specific), implement error handling và loading states, add proper navigation và state management.',
                                'Giai đoạn 6 - Kiểm thử: Viết unit tests cho parsePageSelection() với extensive test cases, viết feature tests cho API endpoint với various scenarios, kiểm thử với real PDFs (simple, complex, large, corrupted), đo performance với different page counts, kiểm thử UI trên multiple platforms (iOS, Android, web), kiểm thử edge cases (empty input, invalid format, out of bounds, huge files).',
                                'Giai đoạn 7 - Đánh giá và tối ưu: Phân tích performance metrics (response time, memory usage), identify bottlenecks, implement optimizations where needed, validate accuracy of extracted text, gather user feedback (if possible), document lessons learned và best practices.',
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Cơ sở lý thuyết',
                'level' => 1,
                'page_break' => true,
                'paragraphs' => [
                    'Chương này trình bày nền tảng lý thuyết về cấu trúc file PDF, cách thức lưu trữ và biểu diễn văn bản trong PDF, các phương pháp trích xuất văn bản, và so sánh các thư viện processing phổ biến. Việc hiểu sâu về cấu trúc PDF là điều kiện tiên quyết để thiết kế và triển khai hệ thống extraction hiệu quả.',
                ],
                'children' => [
                    [
                        'title' => 'Cấu trúc file PDF',
                        'level' => 2,
                        'paragraphs' => [
                            'PDF file được tổ chức thành bốn phần chính: header, body, cross-reference table và trailer. Header chứa version string (ví dụ: "%PDF-1.7") và magic bytes để identify file type. Body chứa các objects định nghĩa nội dung document: pages, text, fonts, images, metadata. Cross-reference table (xref table) lưu trữ byte offsets của tất cả objects trong file để cho phép random access. Trailer chứa pointers đến root object và xref table, cũng như các metadata như encryption info.',
                            'PDF sử dụng object-based structure. Mỗi object có object number và generation number, được tham chiếu bằng indirect references. Có 8 loại objects cơ bản: Boolean, Integer, Real, String, Name, Array, Dictionary, và Stream. Đặc biệt, Dictionary objects (cặp key-value) được sử dụng rộng rãi để mô tả các entities như pages, fonts, images. Stream objects chứa binary data như compressed page content, font programs, hoặc image data.',
                            'Document structure được tổ chức theo cây phân cấp. Root object (Catalog dictionary) trỏ đến Pages object, là root của page tree. Page tree có thể có nhiều levels với intermediate page tree nodes, tối ưu hóa navigation trong documents lớn. Mỗi page object (leaf node) chứa resources dictionary (fonts, images), content stream (drawing instructions), và metadata (media box, crop box, rotation).',
                        ],
                    ],
                    [
                        'title' => 'Text representation trong PDF',
                        'level' => 2,
                        'paragraphs' => [
                            'Văn bản trong PDF không được lưu như plain text mà dưới dạng các text showing operators trong content stream. Content stream là một chuỗi các operators và operands mô tả cách vẽ nội dung lên page. Text được bao bọc giữa BT (Begin Text) và ET (End Text) operators.',
                            'Các text showing operators chính bao gồm: Tj (show text string), TJ (show text with individual glyph positioning), apostrophe (move to next line và show text), quotation mark (set word và character spacing, move to next line và show text). Text string được đặt trong dấu ngoặc đơn hoặc angle brackets, có thể là literal strings hoặc hexadecimal strings.',
                            'Text positioning được kiểm soát bởi text matrix và text state parameters. Td operator translates text matrix by (tx, ty), Tm operator sets text matrix trực tiếp bằng 6 parameters của transformation matrix. Text state bao gồm: font (set by Tf operator với font name và size), character spacing (Tc), word spacing (Tw), horizontal scaling (Tz), leading (TL), text rendering mode (Tr), text rise (Ts).',
                            'Một trong những thách thức lớn nhất trong text extraction là văn bản không được lưu theo thứ tự đọc tự nhiên. PDF defines appearance, not structure. Ví dụ, trong two-column layout, text từ cả hai cột có thể được interleaved trong content stream dựa trên tọa độ y. Extraction tool phải reconstruct reading order bằng cách sắp xếp text theo spatial position.',
                        ],
                    ],
                    [
                        'title' => 'Fonts và encoding',
                        'level' => 2,
                        'paragraphs' => [
                            'PDF hỗ trợ nhiều font types: Type 1 (PostScript fonts), TrueType, Type 3 (user-defined glyphs với arbitrary drawing operations), CIDFonts (Character Identifier fonts cho Asian languages với large character sets), Type 0 (composite fonts). Fonts có thể được embedded (nhúng toàn bộ hoặc subset) hoặc referenced (cài sẵn trên system).',
                            'Encoding maps character codes trong text strings sang glyph IDs trong font. Có nhiều encoding schemes: predefined encodings (StandardEncoding, MacRomanEncoding, WinAnsiEncoding), custom encodings (Differences array modify predefined encoding), CMap (Character Map cho CIDFonts, map character codes sang CIDs), ToUnicode CMap (map character codes trực tiếp sang Unicode). ToUnicode CMap là quan trọng nhất cho text extraction vì nó cung cấp Unicode mapping trực tiếp.',
                            'Quá trình decode text trong PDF: đầu tiên, byte sequence trong text string được interpreted theo encoding của font. Nếu font có ToUnicode CMap, byte sequence được map sang Unicode codepoints. Nếu không, system sử dụng font encoding để map sang glyph names, rồi map glyph names sang Unicode bằng Adobe Glyph List. Nếu không có Unicode mapping, có thể fallback sang glyph name hoặc character code, nhưng kết quả thường không accurate.',
                            'Vấn đề phổ biến: custom fonts không có ToUnicode CMap và sử dụng non-standard encoding có thể extract ra gibberish. Embedded subset fonts đôi khi reorder glyphs, làm cho standard mappings không work. Symbol fonts và dingbat fonts không có semantic meaning, extracted text sẽ là random characters. Các thư viện extraction phải handle gracefully những cases này.',
                        ],
                    ],
                    [
                        'title' => 'Page content streams',
                        'level' => 2,
                        'paragraphs' => [
                            'Mỗi page trong PDF có một hoặc nhiều content streams chứa các instructions để render page content. Content stream là một stream object chứa sequence of operators và operands. Operators là các keywords như "BT", "Tj", "cm", "l", "f". Operands là các values đứng trước operator.',
                            'Content stream thường được compressed bằng filters như FlateDecode (zlib), ASCIIHexDecode, ASCII85Decode, LZWDecode, DCTDecode (JPEG), JPXDecode (JPEG2000). Extraction tool phải decompress stream trước khi parse operators. smalot/pdfparser handles decompression tự động.',
                            'Parsing content stream: tokenize stream thành operators và operands, maintain graphics state stack (operators q/Q push/pop state), track text state khi gặp BT/ET và text operators, extract text strings từ Tj/TJ operators, decode text strings theo font encoding, track positioning để reconstruct reading order, handle edge cases (empty strings, whitespace, newlines).',
                            'Reading order reconstruction là challenging: thu thập tất cả text fragments với positions, sort fragments by y-coordinate (top to bottom) then x-coordinate (left to right), group fragments thành lines dựa trên y-tolerance, group lines thành paragraphs dựa trên spacing, concatenate text với appropriate separators (space, newline). Algorithm cần tuning cho different layouts (single column, multiple columns, mixed).',
                        ],
                    ],
                    [
                        'title' => 'Phương pháp trích xuất văn bản',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Text parsing',
                                'level' => 3,
                                'paragraphs' => [
                                    'Text parsing là phương pháp analyze PDF structure và extract text operators từ content streams. Đây là phương pháp chính xác nhất và nhanh nhất cho PDFs có text layer. Process bao gồm: parse PDF file structure, navigate page tree, get page content streams, decompress streams, parse operators và operands, extract text từ Tj/TJ operators, decode text theo font encoding và ToUnicode CMap, reconstruct reading order từ positioning.',
                                    'Ưu điểm: nhanh (không cần image processing), chính xác (extract actual text data, không phải recognized text), preserve Unicode và special characters, low resource usage (CPU và memory), work với encrypted PDFs (nếu có password). Nhược điểm: không work với image-based PDFs (scanned documents), phụ thuộc vào quality của PDF (malformed PDFs gây errors), complex layouts có thể extract sai reading order, custom fonts không có Unicode mapping extract ra gibberish.',
                                    'smalot/pdfparser sử dụng text parsing approach. Library parse PDF structure, extract text từ mỗi page bằng cách analyze content streams, decode fonts và encodings, và return text as string. API rất đơn giản: $parser->parseFile($path)->getText() cho toàn bộ document, hoặc $page->getText() cho từng page. Internal implementation handles complexity của PDF format.',
                                ],
                            ],
                            [
                                'title' => 'OCR (Optical Character Recognition)',
                                'level' => 3,
                                'paragraphs' => [
                                    'OCR là phương pháp chuyển PDF pages thành images rồi sử dụng machine learning models để recognize text từ images. Đây là phương pháp duy nhất cho scanned documents (PDFs không có text layer). Process: render PDF page thành image (bitmap), preprocess image (deskew, denoise, binarize), segment image thành text regions, recognize characters bằng trained models, post-process results (spell check, language model).',
                                    'Popular OCR engines: Tesseract (open source, Google maintains, hỗ trợ 100+ languages), ABBYY FineReader (commercial, very accurate), Adobe Acrobat OCR, Google Cloud Vision API, Amazon Textract. Tesseract 5.x sử dụng LSTM (Long Short-Term Memory) neural networks, đạt độ chính xác cao với clean scans.',
                                    'Ưu điểm: work với scanned documents và image-based PDFs, có thể process physical documents (chụp ảnh hoặc scan), extract text từ images, photos, screenshots. Nhược điểm: chậm hơn nhiều so với parsing (giây thay vì milliseconds), accuracy phụ thuộc vào image quality, không perfect (recognition errors, typos), resource-intensive (CPU/GPU, memory), không preserve exact formatting, không work tốt với handwriting hoặc decorative fonts.',
                                    'OCR integration không nằm trong phạm vi nghiên cứu hiện tại, nhưng có thể được thêm vào future work. Implementation sẽ cần: detect xem page có text layer không (check content stream có text operators), nếu không có, render page thành image bằng Imagick hoặc GhostScript, pass image sang Tesseract CLI hoặc library, get recognized text, merge với parsed text từ các pages khác.',
                                ],
                            ],
                            [
                                'title' => 'Hybrid approach',
                                'level' => 3,
                                'paragraphs' => [
                                    'Hybrid approach kết hợp text parsing và OCR để xử lý mixed-content PDFs (một số pages có text layer, một số là images). Process: attempt text parsing trên mỗi page, detect xem extracted text có meaningful content không (length, character diversity, not all garbage), nếu parsing thất bại hoặc kết quả là gibberish, fallback sang OCR, merge results từ cả parsing và OCR.',
                                    'Heuristics để detect text-based vs image-based pages: check xem content stream có text operators (BT/ET, Tj/TJ), check extracted text length (quá ngắn có thể là image-only), check character diversity (random characters indicate encoding issues), check presence of XObject images (large images covering whole page likely scanned). Cần balance giữa precision (không OCR khi không cần) và recall (OCR khi thực sự cần).',
                                    'Ưu điểm: tối ưu performance (chỉ OCR khi cần), handle được mixed-content documents, fallback mechanism đảm bảo robustness. Nhược điểm: complexity cao hơn (maintain both parsing và OCR code paths), detection logic có thể không perfect (false positives/negatives), vẫn cần OCR engine và dependencies.',
                                    'Trong tương lai, My Digital Bookstore có thể implement hybrid approach để improve coverage. Tuy nhiên, phần lớn ebooks published commercially đều là text-based PDFs, nên text parsing alone đã cover hầu hết use cases.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Các thư viện PDF text extraction',
                        'level' => 2,
                        'paragraphs' => [
                            'Có nhiều thư viện xử lý PDF trong các ngôn ngữ khác nhau. Việc lựa chọn thư viện phù hợp phụ thuộc vào ngôn ngữ backend, yêu cầu về features, performance, và ease of integration. Phần này khảo sát và so sánh các thư viện phổ biến.',
                        ],
                        'children' => [
                            [
                                'title' => 'smalot/pdfparser (PHP)',
                                'level' => 3,
                                'paragraphs' => [
                                    'smalot/pdfparser là pure PHP library cho PDF parsing và text extraction. Đây là thư viện được chọn cho My Digital Bookstore backend. Key features: pure PHP implementation (không cần external binaries), no dependencies ngoài PHP extensions thông thường, MIT license (permissive, commercial-friendly), simple API ($parser->parseFile($path)->getText()), extract per page ($page->getText()), parse metadata, images, và fonts.',
                                    'Installation đơn giản qua Composer: composer require smalot/pdfparser. Sử dụng cơ bản: $parser = new Parser(); $pdf = $parser->parseFile("file.pdf"); $text = $pdf->getText(); $pages = $pdf->getPages(); foreach ($pages as $page) { $text = $page->getText(); }. API rất intuitive và không require deep knowledge của PDF format.',
                                    'Performance: acceptable cho most ebooks và documents (extract 100-page PDF trong vài giây). Memory usage: reasonable, có thể handle PDFs vài chục MB without issues. Limitations: complex fonts với custom encodings có thể extract incorrectly, very complex layouts (heavily formatted tables) có thể sai reading order, some malformed PDFs cause parsing errors, không hỗ trợ encrypted PDFs without decryption first.',
                                    'Community: active development on GitHub (github.com/smalot/pdfparser), responsive maintainers, decent documentation với examples, used by many PHP projects. Overall: excellent choice cho PHP projects cần basic-to-intermediate PDF text extraction without heavy dependencies.',
                                ],
                            ],
                            [
                                'title' => 'Apache PDFBox (Java)',
                                'level' => 3,
                                'paragraphs' => [
                                    'Apache PDFBox là powerful Java library cho PDF manipulation, bao gồm text extraction, PDF creation, PDF form filling, PDF signing. Đây là industry-standard library với excellent support cho complex PDFs. Features: comprehensive PDF parsing, excellent font handling (including CIDFonts, embedded fonts, ToUnicode CMaps), advanced layout analysis (detect columns, paragraphs, reading order), PDF creation và modification, form filling và digital signatures, encryption support, Apache 2.0 license.',
                                    'Text extraction: PDFTextStripper class provides flexible extraction với options cho sorting, start/end page, line separator, paragraph separator, word separator. Can customize extraction với subclassing. Example: PDDocument document = Loader.loadPDF(file); PDFTextStripper stripper = new PDFTextStripper(); stripper.setStartPage(1); stripper.setEndPage(10); String text = stripper.getText(document);',
                                    'Performance: excellent, optimized cho large documents, multi-threading support. Accuracy: very high, handles complex fonts và encodings correctly in most cases. Limitations: requires Java runtime (not ideal cho pure PHP projects), heavier dependencies, more complex API.',
                                    'Nếu My Digital Bookstore được develop bằng Java/Spring thay vì Laravel, PDFBox sẽ là lựa chọn tốt nhất. Tuy nhiên, integration PDFBox vào PHP project requires Java runtime và inter-process communication (call Java CLI tool từ PHP), tăng complexity và deployment overhead.',
                                ],
                            ],
                            [
                                'title' => 'Python libraries',
                                'level' => 3,
                                'paragraphs' => [
                                    'Python có nhiều libraries cho PDF processing, phổ biến trong data science workflows. PyPDF2: pure Python, simple API, basic features, maintenance issues (project was unmaintained for years, recently revived). pypdf (fork của PyPDF2): actively maintained, improved features. pdfminer.six: focus on text extraction, excellent layout analysis, detect columns và reading order accurately, more complex API but powerful, good for extracting structured data.',
                                    'pdfminer.six example: from pdfminer.high_level import extract_text, extract_pages; text = extract_text("file.pdf"); for page_layout in extract_pages("file.pdf"): for element in page_layout: process(element). Library provides both high-level API (extract_text) và low-level API (extract_pages với layout objects) for fine-grained control.',
                                    'Performance: good, comparable to smalot/pdfparser. Accuracy: pdfminer.six có very good accuracy với complex layouts. Limitations: requires Python runtime, not ideal cho PHP projects unless using microservices architecture hoặc Python subprocess calls.',
                                    'Tương tự PDFBox, Python libraries là excellent nhưng không phù hợp cho Laravel monolith. Có thể consider trong future nếu hệ thống chuyển sang microservices và cần advanced extraction features.',
                                ],
                            ],
                            [
                                'title' => 'So sánh và lựa chọn',
                                'level' => 3,
                                'paragraphs' => [
                                    'Bảng so sánh các thư viện theo các tiêu chí quan trọng: Language: smalot/pdfparser (PHP), PDFBox (Java), pdfminer.six (Python). Dependencies: smalot/pdfparser (None), PDFBox (Java runtime), pdfminer.six (Python runtime). Performance: smalot/pdfparser (Good), PDFBox (Excellent), pdfminer.six (Good). Complex PDFs: smalot/pdfparser (Limited), PDFBox (Excellent), pdfminer.six (Good). Ease of use: smalot/pdfparser (5/5), PDFBox (3/5), pdfminer.six (4/5). License: smalot/pdfparser (MIT), PDFBox (Apache 2.0), pdfminer.six (MIT).',
                                    'Lý do chọn smalot/pdfparser cho My Digital Bookstore: Native PHP - không cần external runtime (Java hoặc Python), simplifies deployment và reduces infrastructure complexity. Zero dependencies - pure PHP, chỉ cần PHP 7.x+ với standard extensions. Ease of integration - tích hợp trực tiếp vào Laravel project qua Composer, use dependency injection. Simple API - developers có thể quickly understand và use without extensive learning. MIT license - permissive, no restrictions cho commercial use.',
                                    'Good enough accuracy - phần lớn ebooks và textbooks có simple-to-moderate layouts, không cần advanced layout analysis của PDFBox. smalot/pdfparser handles adequately. Performance adequate - response time under 5 seconds cho 100 pages là acceptable cho use case của digital bookstore. Proven track record - library used in many production PHP applications, stable và reliable.',
                                    'Trade-offs: smalot/pdfparser không handle complex fonts và very complex layouts as well as PDFBox. Nhưng given constraint là PHP backend và primary use case là ebooks (which generally have clean layouts và standard fonts), smalot/pdfparser là optimal choice. Future work có thể explore fallback mechanisms hoặc hybrid approaches nếu encounter PDFs that extraction poorly.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Page selection và input validation',
                        'level' => 2,
                        'paragraphs' => [
                            'Allowing users chọn specific pages cần extract là important feature để optimize performance và reduce unnecessary processing. Tuy nhiên, user input phải được validate và sanitize carefully để prevent security vulnerabilities và ensure system stability.',
                        ],
                        'children' => [
                            [
                                'title' => 'Page selection syntax',
                                'level' => 3,
                                'paragraphs' => [
                                    'Hệ thống định nghĩa flexible syntax cho page selection: Empty hoặc null input means extract all pages. Comma-separated integers: "1,5,10" means pages 1, 5, and 10. Ranges với hyphen: "30-40" means pages 30 through 40 inclusive (30, 31, 32, ..., 40). Combined: "1,5,10,30-40,100-200" combines individual pages và ranges. Whitespace allowed: "10- 30, 5 , 100" is valid (will be normalized to "10-30,5,100").',
                                    'Tất cả page numbers là 1-based indexing (first page is page 1, not 0), theo convention của PDF viewers và human intuition. Duplicates are removed automatically: "1,1,5,5" becomes [1, 5]. Results are sorted: "5,1,10" returns [1, 5, 10]. Invalid formats rejected với descriptive error messages.',
                                    'Examples: "1" → extract page 1 only. "1,2,3" → extract pages 1, 2, 3. "1-10" → extract pages 1 through 10. "1,5,10-20,50" → extract pages 1, 5, 10 through 20, and 50. "" (empty) → extract all pages.',
                                ],
                            ],
                            [
                                'title' => 'Input validation flow',
                                'level' => 3,
                                'paragraphs' => [
                                    'PdfTextExtractor service implements comprehensive validation in parsePageSelection() method. Flow: Receive input string từ user (can be null, empty, hoặc có value). Return empty array nếu input is null or empty (means all pages). Sanitize: remove all whitespace với preg_replace("/\\s+/", "", $input) để prevent injection attacks hiding trong whitespace.',
                                    'Validate format: check sanitized string matches regex /^[\\d,\\-]+$/ (only digits, commas, hyphens allowed). Nếu không match, throw InvalidArgumentException với message "Invalid page format. Use only numbers, commas, and hyphens." Split by comma: explode(",", $sanitized) thành array of parts.',
                                    'Process each part: nếu part chứa hyphen, parse as range (validate có đúng 1 hyphen, validate start và end are valid integers, validate start <= end, validate end <= totalPages, expand thành array of integers). Nếu part không chứa hyphen, parse as single page number (validate is valid integer, validate > 0, validate <= totalPages). Collect all pages vào array.',
                                    'Post-processing: remove duplicates với array_unique(), sort ascending với sort(), check total count <= 1000 (DoS prevention). Return final array of page numbers. Mọi validation failure throw InvalidArgumentException với specific error message, sẽ được catch bởi controller và return 400 Bad Request with JSON error.',
                                ],
                            ],
                            [
                                'title' => 'Security considerations',
                                'level' => 3,
                                'paragraphs' => [
                                    'Input sanitization: whitespace removal prevents attackers hiding malicious payloads trong spaces, tabs, newlines. Regex validation ensures chỉ có allowed characters, prevents injection attacks (SQL injection, command injection, etc.). Tight validation reduces attack surface.',
                                    'DoS prevention: limit maximum 1000 pages per request prevents users extracting entire huge books (1000+ pages) which could consume excessive CPU và memory. Rate limiting (10 requests/minute) prevents abuse từ single user. Together, these measures protect server resources.',
                                    'Range validation: validate start <= end prevents invalid ranges like "40-30". Validate page numbers <= totalPages prevents out-of-bounds access, which could cause errors hoặc crashes. Bounds checking ensures all operations are safe.',
                                    'Error handling: không expose internal errors (stack traces, file paths) to users. Return user-friendly error messages. Log detailed errors server-side for debugging. Prevent information disclosure through error messages. Authentication và authorization: endpoint requires Sanctum token (user phải đăng nhập). Check user có quyền access book (owns book hoặc book is public). Prevent unauthorized access to PDFs.',
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Thiết kế và triển khai',
                'level' => 1,
                'page_break' => true,
                'paragraphs' => [
                    'Chương này mô tả chi tiết thiết kế kiến trúc và quá trình triển khai hệ thống PDF text extraction trong My Digital Bookstore. Thiết kế tuân theo RESTful principles và Laravel best practices, với separation of concerns giữa controller, service layer và data access.',
                ],
                'children' => [
                    [
                        'title' => 'Kiến trúc tổng thể',
                        'level' => 2,
                        'paragraphs' => [
                            'Hệ thống theo client-server architecture với RESTful API làm communication layer. Backend Laravel expose endpoint POST /api/books/{book}/extract-text, receives authenticated requests từ Flutter frontend. Request flow: User taps "Extract Text" button trong book detail screen → Flutter app shows page selection dialog → User enters page selection và taps "Extract" → Flutter sends POST request với Sanctum token và pages parameter → Laravel middleware verifies authentication → Controller validates authorization (user owns book) → Controller calls PdfTextExtractor service → Service parses page selection, validates, và extracts text → Controller returns JSON response với extracted text và metadata → Flutter displays text trong TextViewerScreen.',
                            'Stateless design: mỗi request is self-contained với authentication token, không rely on server-side sessions. Scalable: stateless nature allows horizontal scaling, add more backend servers behind load balancer. Secure: token-based authentication, input validation, rate limiting protect against attacks. Testable: clear separation of concerns allows unit testing service logic independently of HTTP layer.',
                        ],
                    ],
                    [
                        'title' => 'Thiết kế Backend API',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Endpoint specification',
                                'level' => 3,
                                'paragraphs' => [
                                    'Endpoint: POST /api/books/{book}/extract-text. Method: POST (not GET) vì extraction có thể be resource-intensive và POST more appropriate for actions. Path parameter: {book} is book ID. Request headers: Authorization: Bearer {token} (Sanctum token), Content-Type: application/json.',
                                ],
                                'code' => 'Request Body:
{
  "pages": "1,5,10,30-40,100-200"  // optional, omit for all pages
}

Success Response (200 OK):
{
  "success": true,
  "text": "Extracted text content...",
  "total_pages": 250,
  "extracted_pages": [1, 5, 10, 30, 31, ..., 200],
  "page_count": 142
}

Error Response (400 Bad Request):
{
  "success": false,
  "message": "Invalid range format: 40-30"
}

Error Response (403 Forbidden):
{
  "success": false,
  "message": "You do not have permission to access this book."
}

Error Response (404 Not Found):
{
  "success": false,
  "message": "Book not found."
}',
                            ],
                            [
                                'title' => 'Authentication và authorization',
                                'level' => 3,
                                'paragraphs' => [
                                    'Authentication: endpoint được bảo vệ bởi auth:sanctum middleware. User phải có valid Sanctum token trong Authorization header. Token obtained khi user đăng nhập qua /api/login endpoint. Token stored trong Flutter app (SharedPreferences) và attached to all API requests.',
                                    'Authorization: sau khi authenticate, controller kiểm tra user có quyền access book. Logic: nếu book is public (status = published và không restricted), allow all authenticated users. Nếu book is private hoặc restricted, check user owns book (exists trong user_books table). Nếu user không có permission, return 403 Forbidden.',
                                ],
                            ],
                            [
                                'title' => 'Service layer design',
                                'level' => 3,
                                'paragraphs' => [
                                    'PdfTextExtractor service encapsulates business logic cho PDF text extraction. Class được registered trong AppServiceProvider as singleton để share Parser instance. Methods: parsePageSelection(string|null $input, int $totalPages): array - parse và validate page selection string. parseDocument(string $pdfPath): Document - parse PDF file into Document object. extractText(string $pdfPath, array $pages = []): array - main method, extract text from specified pages. extractFromDocument(Document $document, array $pages = []): array - extract text from already parsed document.',
                                    'Separation of concerns: parsePageSelection() handles input validation (single responsibility). parseDocument() handles PDF parsing (can be mocked in tests). extractText() orchestrates parsing và extraction. extractFromDocument() allows reusing parsed document cho multiple extractions (performance optimization potential).',
                                    'Error handling: methods throw InvalidArgumentException for validation errors (caught by controller, converted to 400 response). Throw RuntimeException for PDF parsing errors (caught by controller, converted to 500 response with safe error message). Exceptions provide descriptive messages suitable for logging và error responses.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Triển khai Backend',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Service implementation',
                                'level' => 3,
                                'paragraphs' => [
                                    'PdfTextExtractor service đã được triển khai trong app/Services/PdfTextExtractor.php. Constructor nhận Parser instance qua dependency injection. parsePageSelection() method implements toàn bộ validation logic như đã mô tả trong chương 2: sanitize input, validate format, parse parts, validate ranges và single pages, check bounds, check max pages, remove duplicates và sort.',
                                    'extractText() method: call parseDocument() để parse PDF file, get total pages từ document, nếu pages array empty, extract all pages, nếu pages specified, validate và extract chỉ specified pages, return array với text, total_pages, extracted_pages, page_count. Implementation handles errors gracefully với try-catch và throw informative exceptions.',
                                ],
                            ],
                            [
                                'title' => 'Controller implementation',
                                'level' => 3,
                                'paragraphs' => [
                                    'BookTextExtractionController handles HTTP layer. extractText() method: validate request (pages parameter is optional string), authorize user (check user owns book hoặc book is public), get PDF path từ book model (storage/app/books/{id}.pdf), call PdfTextExtractor service với PDF path và parsed pages, return JSON response với extracted text và metadata.',
                                    'Error handling: catch InvalidArgumentException (validation errors) và return 400 response với error message, catch RuntimeException (parsing errors) và return 500 response với generic message (không expose internal details), catch other exceptions và log, return 500 với generic error message.',
                                ],
                            ],
                            [
                                'title' => 'Route registration',
                                'level' => 3,
                                'paragraphs' => [
                                    'Route defined trong routes/api.php: Route::post("/books/{book}/extract-text", [BookTextExtractionController::class, "extractText"])->middleware("auth:sanctum"); Middleware auth:sanctum ensures user is authenticated. {book} parameter automatically resolves Book model qua route model binding.',
                                ],
                            ],
                            [
                                'title' => 'Rate limiting',
                                'level' => 3,
                                'paragraphs' => [
                                    'Rate limiting implemented trong app/Providers/AppServiceProvider.php hoặc routes file: RateLimiter::for("pdf-extraction", function (Request $request) { return Limit::perMinute(10)->by($request->user()->id); }); Apply to route: ->middleware("throttle:pdf-extraction"). Limit 10 requests per minute per user prevents abuse.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Thiết kế Frontend UI',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'User flow',
                                'level' => 3,
                                'paragraphs' => [
                                    'User flow cho PDF text extraction: User navigates to book detail screen. Taps "Extract Text" button (positioned next to "Download PDF" button). Bottom sheet (mobile) hoặc dialog (tablet/desktop) appears với page selection options. User sees two radio options: "All pages" (selected by default), "Specific pages" (với text input field). Nếu chọn "Specific pages", user enters page selection syntax trong text field. TextField shows hint text "e.g., 1,5,10,30-40" và helper text "Enter page numbers or ranges". Real-time validation: nếu input invalid, error text appears dưới field, "Extract" button disabled.',
                                    'User taps "Extract" button. Dialog closes, loading indicator appears với message "Extracting text...". Flutter sends API request. Khi response received: navigate to TextViewerScreen với extracted text data. TextViewerScreen displays: AppBar với title "Extracted Text" và back button, collapsible metadata card showing total pages, extracted pages, page count, scrollable selectable text widget với extracted content, action buttons: Copy (to clipboard), Save (to file), Share (optional).',
                                ],
                            ],
                            [
                                'title' => 'Page selection dialog',
                                'level' => 3,
                                'paragraphs' => [
                                    'PageSelectionDialog widget: showModalBottomSheet (mobile) hoặc showDialog (tablet/desktop based on screen size). Content: Column với: title "Select pages to extract", RadioListTile "All pages" với value empty string, RadioListTile "Specific pages" với value "specific", Nếu "Specific pages" selected: TextField với decoration (label, hint, helper text, error text), InputFormatters để restrict input to [\\d,\\s\\-], onChange callback để validate realtime.',
                                    'Validation logic: nếu user enters invalid format (letters, special chars), show error "Invalid format". Nếu user enters invalid range (40-30), show error "Invalid range". Disable "Extract" button khi input invalid. Enable khi valid hoặc "All pages" selected.',
                                ],
                            ],
                            [
                                'title' => 'Text viewer screen',
                                'level' => 3,
                                'paragraphs' => [
                                    'TextViewerScreen widget: Scaffold với AppBar và body. AppBar: title "Extracted Text", leading back button, actions: IconButton copy (ContentCopy icon), IconButton save (SaveAlt icon), IconButton share (Share icon, optional). Body: ListView với metadata card và text content. Metadata card: ExpansionTile (collapsible) with title "Extraction Info", expanded children: ListTile "Total pages: 250", ListTile "Extracted pages: 1, 5, 10, 30-40, ...", ListTile "Page count: 142".',
                                    'Text content: Divider, Padding child: SelectableText với extracted text, style: TextStyle với fontSize configurable (user preference), fontFamily: monospace hoặc user preference, color: respect theme (light/dark). SelectableText allows user select portions và copy with system UI. Scrollable để accommodate long text.',
                                ],
                            ],
                            [
                                'title' => 'Actions implementation',
                                'level' => 3,
                                'paragraphs' => [
                                    'Copy to clipboard: import "package:flutter/services.dart"; onPressed: () { Clipboard.setData(ClipboardData(text: extractedText)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied to clipboard"))); }. Simple và works across all platforms.',
                                    'Save to file: import "package:path_provider/path_provider.dart"; import "dart:io"; Mobile/Desktop: getApplicationDocumentsDirectory(), create file với unique name (extracted_text_timestamp.txt), write text to file, show snackbar với success message. Web: create Blob với text content, create anchor element với download attribute, trigger click, revoke object URL. Platform-specific implementations handled với kIsWeb constant.',
                                    'Share (optional): import "package:share_plus/share_plus.dart"; Share.share(extractedText, subject: "Extracted text from book"); Works on mobile, opens system share sheet. On desktop/web, may not be available, hide button hoặc disable.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Triển khai Frontend',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Service class',
                                'level' => 3,
                                'paragraphs' => [
                                    'PdfTextService singleton service trong lib/services/pdf_text_service.dart. Constructor receives Dio instance for HTTP requests. extractText() method: sends POST request to /api/books/{bookId}/extract-text với pages parameter trong request body, returns ExtractedText model parsed từ response JSON, throws exceptions on errors (caught by UI layer và displayed as error messages).',
                                ],
                            ],
                            [
                                'title' => 'Model class',
                                'level' => 3,
                                'paragraphs' => [
                                    'ExtractedText model trong lib/models/extracted_text.dart. Properties: String text - extracted text content, int totalPages - total pages trong PDF, List<int> extractedPages - list of page numbers extracted, int pageCount - count of extracted pages. Factory constructor fromJson() parses JSON response: text = json["text"], totalPages = json["total_pages"], extractedPages = List<int>.from(json["extracted_pages"]), pageCount = json["page_count"].',
                                ],
                            ],
                            [
                                'title' => 'UI implementation',
                                'level' => 3,
                                'paragraphs' => [
                                    'PageSelectionDialog: StatefulWidget maintaining selected option (all/specific) và text input value trong state. Build method returns appropriate UI based on platform (BottomSheet hoặc AlertDialog). Validation logic trong onChange callback, updates error text và button enabled state. OnExtract callback passes selected pages back to parent.',
                                    'TextViewerScreen: StatelessWidget receiving ExtractedText object. Build method constructs UI như described. Copy/Save/Share actions implemented as described. State management: sử dụng Provider hoặc Riverpod để manage loading state và extracted text state. When user taps Extract button, set loading = true, call service, on success set extractedText và navigate, on error show snackbar với error message.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Ứng dụng vào My Digital Bookstore',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Use cases',
                                'level' => 3,
                                'paragraphs' => [
                                    'Sinh viên extract quotes: sinh viên đang viết essay hoặc research paper, cần extract exact quotes từ textbook với page numbers, sử dụng tính năng này thay vì typing manually (prone to typos), paste trực tiếp vào document với proper citation.',
                                    'Nghiên cứu viên extract references: researcher cần extract reference sections từ academic papers, extract bibliography pages (thường ở cuối book), copy references để add vào reference manager hoặc own bibliography.',
                                    'Dịch thuật: người đọc gặp đoạn văn bản khó hiểu bằng tiếng nước ngoài, extract đoạn đó, paste vào Google Translate hoặc translation tool, hiểu nghĩa rồi tiếp tục đọc.',
                                    'Ghi chú và highlights: người đọc muốn ghi chú lại key points từ book, extract relevant pages hoặc paragraphs, save vào note-taking app (Evernote, Notion), build personal knowledge base.',
                                    'Accessibility: người khiếm thị sử dụng screen reader, extract text và pass sang text-to-speech engine, listen to book instead of reading visually, improve access to educational materials.',
                                ],
                            ],
                            [
                                'title' => 'Integration points',
                                'level' => 3,
                                'paragraphs' => [
                                    'Book detail screen: add "Extract Text" button next to existing "Download PDF" và "Read Online" buttons. Button styled consistently với other action buttons. OnPressed: show PageSelectionDialog.',
                                    'My Books screen: trong future, có thể add bulk extraction feature: select multiple books, extract all of them to create personal text corpus cho full-text search hoặc analysis. Currently out of scope nhưng architecture supports expansion này.',
                                    'Search feature: trong future, extracted text có thể be indexed với Elasticsearch hoặc similar full-text search engine, enable searching across user\'s entire library for keywords, phrases, topics. Powerful feature for researchers và students.',
                                ],
                            ],
                            [
                                'title' => 'Business value',
                                'level' => 3,
                                'paragraphs' => [
                                    'Enhanced user experience: tính năng extraction makes books more useful, not just readable but also analyzable và reusable, increase user satisfaction và engagement, differentiate from competitors.',
                                    'Competitive advantage: nhiều digital bookstores không offer text extraction (thường vì DRM concerns), offering this (for purchased books) is a value-add, attract power users (students, researchers) who need this feature.',
                                    'Accessibility compliance: providing text extraction helps comply với accessibility standards (WCAG, ADA), demonstrate commitment to inclusive design, expand potential user base to include visually impaired users.',
                                    'Foundation for advanced features: text extraction is building block cho many advanced features: full-text search, AI summarization, sentiment analysis, topic modeling, recommendation based on content similarity, all these require extracted text as input.',
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Kiểm thử và đánh giá',
                'level' => 1,
                'page_break' => true,
                'paragraphs' => [
                    'Chương này mô tả chiến lược kiểm thử, các test cases, kết quả kiểm thử và đánh giá toàn diện về performance, accuracy và usability của hệ thống PDF text extraction. Kiểm thử đầy đủ đảm bảo hệ thống hoạt động đúng đắn, an toàn và hiệu quả trong production.',
                ],
                'children' => [
                    [
                        'title' => 'Chiến lược kiểm thử',
                        'level' => 2,
                        'paragraphs' => [
                            'Kiểm thử được tiến hành ở nhiều levels để đảm bảo chất lượng toàn diện: Unit tests cho individual methods và functions, đặc biệt là parsePageSelection() với nhiều edge cases. Feature tests cho API endpoints, verify request-response cycle end-to-end trong backend. Widget tests cho Flutter UI components, verify rendering và interaction logic. Integration tests cho complete user flows từ button click đến text display. Manual testing với real PDFs và real devices để validate actual user experience.',
                            'Test data: tạo variety of test PDFs: simple text PDF (single column, standard fonts), complex PDF (multiple columns, tables, figures), large PDF (500+ pages), small PDF (single page), PDF với custom fonts, corrupted PDF (intentionally malformed), encrypted PDF (password-protected). Use real-world ebooks khi possible để ensure relevance.',
                        ],
                    ],
                    [
                        'title' => 'Kiểm thử Backend',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Unit tests',
                                'level' => 3,
                                'paragraphs' => [
                                    'Tests cho parsePageSelection() trong tests/Unit/PdfTextExtractorTest.php. Test cases: Valid inputs: "1,5,10" → [1, 5, 10], "30-40" → [30, 31, ..., 40], "1,5,10,30-40" → [1, 5, 10, 30, ..., 40], "" → [], null → []. Invalid inputs: "abc" → exception "Invalid page format", "1..5" → exception "Invalid range format", "40-30" → exception "Invalid range (start > end)", "999999" → exception "Page exceeds total pages". Edge cases: "  " (whitespace only) → [], "1,1,1" (duplicates) → [1], "10- 30, 5 , 100" (with whitespace) → [5, 10, ..., 30, 100] (sorted, whitespace removed).',
                                    'Tests cho extractText() method: mock Parser và Document, verify parsePageSelection() called với correct args, verify getText() called on correct pages, verify output structure (text, total_pages, extracted_pages, page_count), verify exceptions handled correctly.',
                                ],
                            ],
                            [
                                'title' => 'Feature tests',
                                'level' => 3,
                                'paragraphs' => [
                                    'Tests cho API endpoint trong tests/Feature/PdfTextExtractionTest.php. Test cases: Extract all pages (empty pages param): send POST /api/books/{id}/extract-text với empty body, expect 200 response, verify response structure, verify text returned. Extract specific pages: send POST với {"pages": "1,5,10"}, verify only specified pages extracted, verify extracted_pages array matches. Extract ranges: send với {"pages": "30-40"}, verify all pages trong range extracted.',
                                    'Authorization tests: unauthorized request (no token) → 401, forbidden request (user doesn\'t own book) → 403, authorized request → 200. Invalid input tests: invalid format {"pages": "abc"} → 400 với error message, invalid range {"pages": "40-30"} → 400, out of bounds {"pages": "999"} → 400. DoS prevention: request với >1000 pages → 400 với appropriate message. Rate limiting: send >10 requests trong minute → 429 Too Many Requests.',
                                ],
                            ],
                            [
                                'title' => 'Testing với real PDFs',
                                'level' => 3,
                                'paragraphs' => [
                                    'Manual testing với variety of PDFs: Simple text PDF: create sample PDF với plain text, single column, standard fonts (Times New Roman), extract và verify text matches original exactly. Complex layout PDF: create PDF với two columns, tables, headers/footers, extract và check reading order (may not be perfect but should be reasonable). Custom fonts PDF: use PDF với embedded subset fonts, custom encoding, extract và check for gibberish (expected limitation, document this). Large PDF: test với 500-page PDF, measure extraction time, verify no crashes hoặc memory issues.',
                                    'Corrupted PDF: intentionally corrupt PDF file (modify random bytes), attempt extraction, expect graceful failure với error message (not crash). Encrypted PDF: create password-protected PDF, attempt extraction, verify error handling (currently not supported, return appropriate error).',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Kiểm thử Frontend',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Widget tests',
                                'level' => 3,
                                'paragraphs' => [
                                    'Tests cho PageSelectionDialog: verify dialog renders correctly, verify radio buttons work (switch between all/specific), verify TextField appears when "Specific pages" selected, verify input validation works (valid input enables button, invalid input disables và shows error), verify Extract callback called với correct value.',
                                    'Tests cho TextViewerScreen: verify screen renders với provided text, verify metadata displays correctly, verify text is selectable, mock copy action và verify Clipboard.setData called, mock save action và verify file operations.',
                                ],
                            ],
                            [
                                'title' => 'Integration tests',
                                'level' => 3,
                                'paragraphs' => [
                                    'End-to-end flow tests: launch app, login, navigate to book detail, tap "Extract Text", dialog appears, enter page selection, tap Extract, verify loading indicator, verify navigation to TextViewerScreen, verify text displayed, tap Copy button, verify snackbar, tap back, verify returned to book detail.',
                                    'Error scenarios: enter invalid page selection, tap Extract, verify error message shown, dismiss error, retry với valid input. Network error simulation: mock network failure, attempt extraction, verify error handling (snackbar với "Network error" message).',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Đánh giá hiệu năng',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Backend performance',
                                'level' => 3,
                                'paragraphs' => [
                                    'Performance measurements với different page counts: Extract 1 page: average ~50ms, well under 100ms target. Extract 10 pages: average ~300ms, under 500ms target. Extract 100 pages: average ~3 seconds, under 5s target. Extract 1000 pages: average ~25 seconds, under 30s target (acceptable cho this extreme case). Memory usage: peak memory ~150MB cho 500-page PDF, acceptable given available resources.',
                                    'Bottlenecks identified: PDF parsing (initial parseFile) takes majority of time, subsequent page extraction is fast. Decompression của content streams có thể be expensive cho heavily compressed PDFs. Font decoding với complex encodings adds overhead. Potential optimizations: cache parsed Document objects (trade-off: memory), parallel processing của pages (trade-off: complexity), streaming extraction for very large files (future work).',
                                ],
                            ],
                            [
                                'title' => 'Frontend performance',
                                'level' => 3,
                                'paragraphs' => [
                                    'UI responsiveness: page selection dialog opens instantly (<50ms). Text input validation runs smoothly without lag. TextViewerScreen renders large text (1MB+) without stuttering thanks to efficient SelectableText widget. Copy to clipboard: instant operation (<10ms). Save to file: completes trong <2 seconds cho 1MB text file.',
                                    'Network performance: API request với extracted text response (few hundred KB) completes trong <1 second on good connection. Loading indicator provides feedback during wait. Graceful degradation on slow network: timeouts configured appropriately (30s), error messages inform user.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Đánh giá chất lượng',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Accuracy',
                                'level' => 3,
                                'paragraphs' => [
                                    'Text extraction accuracy: Simple PDFs: 100% accurate, extracted text matches original exactly, character-for-character. Standard ebooks: 95-99% accurate, occasional issues với line breaks hoặc spacing, but readable và usable. Complex layouts: 80-90% accurate, reading order may be imperfect (columns may interleave), but most text extracted correctly. Custom fonts: variable (50-100%), depends on presence of ToUnicode CMap, without CMap extraction may produce gibberish.',
                                    'Unicode và special characters: handled correctly for most cases, accented characters (é, ñ, ü) extracted properly, non-Latin scripts (Chinese, Arabic, etc.) extracted correctly if font has proper Unicode mapping, emoji và symbols: may or may not work depending on font.',
                                ],
                            ],
                            [
                                'title' => 'Usability',
                                'level' => 3,
                                'paragraphs' => [
                                    'User interface: intuitive, users quickly understand page selection syntax with hint text, error messages helpful và specific, copy/save actions work as expected, no confusion reported trong testing. Accessibility: screen reader compatible (proper semantic labels), keyboard navigation works (web/desktop), sufficient contrast ratios, follows Material Design accessibility guidelines.',
                                ],
                            ],
                            [
                                'title' => 'Limitations discovered',
                                'level' => 3,
                                'paragraphs' => [
                                    'Limitations encountered during testing: Complex fonts: PDFs với custom fonts và non-standard encoding extract incorrectly, produces gibberish characters, no easy fix without advanced font analysis. Complex layouts: heavily formatted documents với multiple columns, tables, text boxes extract với imperfect reading order, columns may interleave, table structure lost (becomes plain text). Tables: table structure không preserved, extracted as linear text, cell boundaries lost, alignment information lost.',
                                    'Images và graphics: image-based text không extracted (OCR needed), decorative elements extracted as garbage characters (filtered out best effort), diagrams và charts lost entirely. Formatting: bold, italic, underline formatting lost, font sizes không preserved, colors lost, all output is plain text. Performance với huge files: files >100MB có thể cause memory issues, extraction time becomes excessive (>1 minute), may need pagination hoặc streaming approach.',
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Kết luận và hướng phát triển',
                'level' => 1,
                'page_break' => true,
                'paragraphs' => [
                    'Chương cuối tổng kết những gì đã đạt được, đánh giá đóng góp của nghiên cứu, thừa nhận các hạn chế, và đề xuất hướng phát triển trong tương lai cho hệ thống PDF text extraction trong My Digital Bookstore.',
                ],
                'children' => [
                    [
                        'title' => 'Tổng kết',
                        'level' => 2,
                        'paragraphs' => [
                            'Nghiên cứu này đã thành công trong việc phân tích, thiết kế và triển khai một hệ thống trích xuất văn bản từ PDF hoàn chỉnh, được tích hợp vào ứng dụng Hiệu sách điện tử My Digital Bookstore. Quá trình nghiên cứu bắt đầu với việc tìm hiểu sâu về cấu trúc file PDF theo tiêu chuẩn ISO 32000, cách PDF lưu trữ và biểu diễn văn bản thông qua operators, fonts và encoding schemes, cũng như các thách thức inherent trong việc extract structured text từ presentation-oriented format.',
                            'Sau giai đoạn nghiên cứu lý thuyết, các phương pháp trích xuất văn bản đã được khảo sát và so sánh: text parsing, OCR, và hybrid approaches. Dựa trên phân tích trade-offs và requirements của hệ thống, text parsing bằng thư viện smalot/pdfparser được chọn làm giải pháp chính cho backend Laravel. Thư viện này cung cấp balance tốt giữa ease of integration (pure PHP, no external dependencies), performance (acceptable cho typical use cases), và accuracy (sufficient cho most ebooks).',
                            'Hệ thống được triển khai với kiến trúc RESTful rõ ràng, bao gồm backend Laravel với PdfTextExtractor service encapsulating business logic, API endpoint bảo mật bằng Sanctum authentication, input validation nghiêm ngặt với sanitization và bounds checking, rate limiting để prevent abuse, và comprehensive error handling. Frontend Flutter cung cấp user experience trực quan với page selection dialog cho phép users chọn pages linh hoạt, text viewer screen với selectable text và action buttons, và proper error handling với user-friendly messages.',
                            'Kết quả kiểm thử cho thấy hệ thống đáp ứng yêu cầu về chức năng, performance và security. Unit tests và feature tests coverage đầy đủ đảm bảo code quality. Performance measurements xác nhận response times acceptable (dưới 5 giây cho 100 pages). Accuracy testing với various PDFs cho thấy 95-99% accuracy với standard ebooks, mặc dù có limitations với complex fonts và layouts. User feedback (trong testing) positive về usability và intuitiveness của UI.',
                        ],
                    ],
                    [
                        'title' => 'Đóng góp',
                        'level' => 2,
                        'paragraphs' => [
                            'Nghiên cứu này đóng góp vào cả lý thuyết và thực tiễn trong lĩnh vực xử lý tài liệu số và phát triển ứng dụng hiệu sách điện tử. Về mặt lý thuyết, bài tiểu luận cung cấp một overview comprehensive về công nghệ PDF, từ cấu trúc file đến text representation, fonts và encoding, phù hợp làm tài liệu tham khảo cho students và developers muốn hiểu sâu về PDF processing.',
                            'Về mặt thực tiễn, hệ thống đã triển khai mang lại giá trị cụ thể cho người dùng My Digital Bookstore. Tính năng extraction cho phép sinh viên, researchers và general readers extract quotes, references, và passages từ ebooks một cách dễ dàng, tăng cường productivity và learning experience. Accessibility được cải thiện, mở rộng khả năng tiếp cận sách điện tử cho người khiếm thị thông qua text-to-speech.',
                            'Kiến trúc và implementation patterns được demonstrate trong nghiên cứu - service layer separation, input validation, error handling, RESTful API design, Flutter UI patterns - có thể be reused và adapted cho các features tương tự trong My Digital Bookstore hoặc other projects. Code quality cao với comprehensive tests và documentation tạo foundation vững chắc cho maintenance và extension.',
                            'Quan trọng nhất, tính năng PDF text extraction là building block cho nhiều advanced features trong roadmap dài hạn: full-text search across user library với Elasticsearch, AI-powered summarization và key insights extraction, content-based recommendations, sentiment analysis và topic modeling. Việc có extracted text làm structured data input là prerequisite cho tất cả những features này.',
                        ],
                    ],
                    [
                        'title' => 'Hạn chế',
                        'level' => 2,
                        'paragraphs' => [
                            'Mặc dù hệ thống đạt được mục tiêu chính, vẫn tồn tại một số hạn chế cần được acknowledge. Thứ nhất, việc không hỗ trợ OCR nghĩa là image-based PDFs (scanned documents) không thể extract được text. Đây là limitation lớn nếu users muốn extract từ older books hoặc photocopied materials. Integration OCR sẽ require additional dependencies (Tesseract) và significantly increase processing time.',
                            'Thứ hai, complex layouts như multiple columns, tables, và intricate formatting có thể extract với imperfect reading order. smalot/pdfparser làm reasonable job với simple layouts nhưng không sophisticated như Apache PDFBox trong việc reconstruct reading order. Users có thể encounter text that is jumbled hoặc out of sequence trong extreme cases.',
                            'Thứ ba, custom fonts không có ToUnicode CMap mapping extract ra gibberish characters. Đây là inherent limitation của PDFs mà không có standard Unicode mapping. Without advanced font analysis (reverse engineer encoding từ glyph shapes), không có easy solution. Users cần aware rằng không phải mọi PDF sẽ extract perfectly.',
                            'Thứ tư, formatting information (bold, italic, font sizes, colors) completely lost trong extraction. Output là plain text. Nếu users cần preserve formatting, they would need alternative approach (export từ PDF editor như Adobe Acrobat). Thứ năm, very large PDFs (hundreds of MB, thousands of pages) có thể cause performance issues (memory exhaustion, timeout). Current implementation loads entire document vào memory, không ideal cho extreme cases.',
                            'Cuối cùng, rate limiting và DoS prevention, mặc dù necessary cho security, có thể frustrate legitimate power users muốn extract nhiều books quickly. Balance giữa security và usability cần constant tuning based on actual usage patterns.',
                        ],
                    ],
                    [
                        'title' => 'Hướng phát triển',
                        'level' => 2,
                        'children' => [
                            [
                                'title' => 'Ngắn hạn',
                                'level' => 3,
                                'paragraphs' => [
                                    'Cải thiện error messages: làm error messages more helpful với suggestions. Ví dụ, khi encounter PDF với custom fonts, suggest "This PDF uses custom fonts. Try a different PDF or contact support." Provide troubleshooting tips in app.',
                                    'Progress indicator cho large extractions: currently chỉ có loading spinner. For large PDFs, implement progress bar showing percentage completed, estimated time remaining. Improve perceived performance và reduce user anxiety.',
                                    'Cache extracted text: store extracted text trong database với book_id, pages, và extracted_text. Reuse cached text for identical requests. Trade-off: storage space vs performance. Implement cache expiration policy.',
                                    'Export formats: beyond plain text, export sang multiple formats: .txt (current), .md (Markdown với basic formatting preserved as headings, lists), .html (HTML với basic styling), .json (structured format cho programmatic use). Dropdown để select format trong TextViewerScreen.',
                                ],
                            ],
                            [
                                'title' => 'Trung hạn',
                                'level' => 3,
                                'paragraphs' => [
                                    'OCR integration: integrate Tesseract OCR engine để support scanned PDFs. Detect pages without text layer, automatically fall back to OCR. Show warning về slower processing. Require Tesseract installed on server (add to deployment docs).',
                                    'Preserve basic formatting: attempt to preserve paragraph boundaries, headings (based on font size), lists (based on indentation và bullets). Output structured Markdown instead of plain text. Challenging nhưng doable với advanced parsing.',
                                    'Table detection và extraction: detect table structures trong PDF, extract as CSV hoặc Markdown table. Libraries like Tabula (Python) specialize trong table extraction, có thể integrate. Useful cho textbooks với many tables.',
                                    'Search highlighting trong extracted text: nếu user searched cho keyword trước khi extracting, highlight keyword trong TextViewerScreen. Use TextSpan với background color để highlight. Improve discoverability.',
                                ],
                            ],
                            [
                                'title' => 'Dài hạn',
                                'level' => 3,
                                'paragraphs' => [
                                    'Full-text search across library: index extracted text từ all books trong user library với Elasticsearch hoặc Meilisearch. Implement search screen cho phép search entire library. Return results ranked by relevance với snippets. Extremely powerful feature cho researchers.',
                                    'AI-powered summarization: use GPT-4, Claude hoặc open-source models (BART, T5) để generate summaries của extracted text. Show summary alongside full text trong TextViewerScreen. Help users quickly grasp main points. Tiết kiệm thời gian.',
                                    'Language translation: integrate translation APIs (Google Translate, DeepL) để translate extracted text. Support multiple target languages. Useful cho reading foreign language books. Show original và translation side-by-side.',
                                    'Text-to-speech: convert extracted text to speech với TTS engines (Google TTS, Amazon Polly, local TTS). Provide audio playback controls. Improve accessibility significantly. Cho phép "listening to books" while multitasking.',
                                    'Annotation và note-taking: allow users annotate extracted text, highlight important parts, add notes. Link annotations back to original PDF pages. Sync annotations across devices. Build personal knowledge base. Integration với note-taking apps như Notion, Evernote.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Kết luận cuối cùng',
                        'level' => 2,
                        'paragraphs' => [
                            'PDF text extraction là chức năng quan trọng và có giá trị trong hệ thống hiệu sách điện tử hiện đại. Nghiên cứu này đã chứng minh rằng việc triển khai tính năng này là khả thi, practical và beneficial cho người dùng. Qua quá trình từ nghiên cứu lý thuyết về PDF structure, khảo sát các phương pháp extraction, lựa chọn và integrate thư viện phù hợp, thiết kế API và UI, đến kiểm thử và đánh giá, một hệ thống hoàn chỉnh đã được xây dựng thành công.',
                            'Kết quả là một tính năng robust, secure và user-friendly cho phép người dùng My Digital Bookstore extract text từ ebooks một cách dễ dàng với page selection linh hoạt. Hệ thống handle gracefully các edge cases và errors, protect against security vulnerabilities, và deliver acceptable performance cho typical use cases. Mặc dù tồn tại limitations với complex PDFs và scanned documents, implementation hiện tại cover được hầu hết use cases trong thực tế.',
                            'Quan trọng hơn, tính năng này tạo foundation vững chắc cho nhiều advanced features trong future roadmap như full-text search, AI summarization và text-to-speech. Extracted text là raw material cho countless applications của machine learning và natural language processing. Investment vào PDF text extraction không chỉ mang lại immediate value cho users mà còn open doors cho innovation trong tương lai.',
                            'Công nghệ PDF processing tiếp tục evolve với PDF 2.0 standard, improved tooling và growing ecosystem. My Digital Bookstore positioned tốt để leverage những advances này. Với foundation đã được establish trong nghiên cứu này, việc integrate new technologies và expand capabilities sẽ straightforward. Hệ thống sẵn sàng scale và adapt theo nhu cầu người dùng trong tương lai.',
                        ],
                    ],
                ],
            ],
        ];
    }

    protected function references(): array
    {
        return [
            '1. Adobe Systems. (2008). PDF Reference, Sixth Edition: Adobe Portable Document Format Version 1.7. Adobe Press. https://www.adobe.com/devnet/pdf/pdf_reference.html',
            '2. ISO 32000-2:2020. Document management — Portable document format — Part 2: PDF 2.0. International Organization for Standardization.',
            '3. smalot/pdfparser. (2024). PdfParser - PHP Library for PDF Parsing. GitHub repository. https://github.com/smalot/pdfparser',
            '4. Apache Software Foundation. (2024). Apache PDFBox - A Java PDF Library. https://pdfbox.apache.org/',
            '5. pdfminer.six. (2024). Python PDF Parser and Analyzer. GitHub repository. https://github.com/pdfminer/pdfminer.six',
            '6. Laravel Documentation. (2024). Laravel 12.x Official Documentation - Authentication with Sanctum. https://laravel.com/docs/12.x/sanctum',
            '7. Flutter Team. (2024). Flutter 3 Documentation - Material Design 3. https://docs.flutter.dev/ui/material',
            '8. Fielding, R. T. (2000). Architectural Styles and the Design of Network-based Software Architectures. Doctoral dissertation, University of California, Irvine.',
            '9. OWASP Foundation. (2024). OWASP Top Ten Web Application Security Risks. https://owasp.org/www-project-top-ten/',
            '10. Tesseract OCR. (2024). Tesseract Open Source OCR Engine. GitHub repository. https://github.com/tesseract-ocr/tesseract',
        ];
    }

    protected function renderAppendixContent(Section $section): void
    {
        $this->addHeading($section, 'Phụ lục A: Cấu trúc file PDF', 2, false);
        $this->addParagraph($section, 'Ví dụ về cấu trúc cơ bản của file PDF:');
        $this->addCodeBlock($section, '%PDF-1.7
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj

2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj

3 0 obj
<< /Type /Page /Parent 2 0 R /Resources 4 0 R /MediaBox [0 0 612 792] /Contents 5 0 R >>
endobj

4 0 obj
<< /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >> >> >>
endobj

5 0 obj
<< /Length 44 >>
stream
BT
/F1 12 Tf
100 700 Td
(Hello World) Tj
ET
endstream
endobj

xref
0 6
trailer
<< /Size 6 /Root 1 0 R >>
%%EOF');

        $section->addTextBreak();
        $this->addHeading($section, 'Phụ lục B: Text operators trong PDF', 2, false);
        $this->addParagraph($section, 'Các operators phổ biến để hiển thị văn bản:');
        $this->addCodeBlock($section, 'BT                  % Begin text
/F1 12 Tf           % Set font (F1) and size (12)
100 700 Td          % Translate to position (100, 700)
(Hello) Tj          % Show text string
50 0 Td             % Move 50 units right
(World) Tj          % Show text string
ET                  % End text');

        $section->addTextBreak();
        $this->addHeading($section, 'Phụ lục C: Page selection test cases', 2, false);
        $this->addParagraph($section, 'Bảng test cases cho parsePageSelection() method:');
        $this->addParagraph($section, 'Input: "1,5,10" | Expected: [1, 5, 10] | Status: Pass');
        $this->addParagraph($section, 'Input: "30-40" | Expected: [30, 31, ..., 40] | Status: Pass');
        $this->addParagraph($section, 'Input: "1,5,10,30-40" | Expected: [1, 5, 10, 30, ..., 40] | Status: Pass');
        $this->addParagraph($section, 'Input: "" | Expected: [] | Status: Pass');
        $this->addParagraph($section, 'Input: "abc" | Expected: Exception | Status: Pass');
        $this->addParagraph($section, 'Input: "40-30" | Expected: Exception (start > end) | Status: Pass');
        $this->addParagraph($section, 'Input: "999999" | Expected: Exception (exceeds total) | Status: Pass');

        $section->addTextBreak();
        $this->addHeading($section, 'Phụ lục D: API request/response examples', 2, false);
        $this->addParagraph($section, 'Ví dụ request trích xuất specific pages:');
        $this->addCodeBlock($section, 'POST /api/books/123/extract-text
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGci...
Content-Type: application/json

{
  "pages": "1,5,10,30-40"
}');

        $this->addParagraph($section, 'Ví dụ response thành công:');
        $this->addCodeBlock($section, '{
  "success": true,
  "text": "Chapter 1: Introduction\\n\\nThis is the introduction...",
  "total_pages": 250,
  "extracted_pages": [1, 5, 10, 30, 31, 32, ..., 40],
  "page_count": 13
}');

        $section->addTextBreak();
        $this->addHeading($section, 'Phụ lục E: Screenshots giao diện', 2, false);
        $this->addParagraph($section, 'Page Selection Dialog: Dialog với radio buttons cho "All pages" và "Specific pages", text field để nhập page selection syntax, và nút "Extract".');
        $this->addParagraph($section, 'Text Viewer Screen: AppBar với title "Extracted Text" và action buttons, metadata card hiển thị thông tin extraction, scrollable selectable text widget với extracted content.');
    }
}
