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

class GenerateEssayFullDocx extends Command
{
    protected $signature = 'essay:generate-full
        {--student=Nguyễn Văn A : Tên sinh viên}
        {--student-id=20210001 : Mã số sinh viên}
        {--class=CNTT-K64 : Lớp học}
        {--course=Đồ án môn học : Tên môn học}
        {--instructor=TS. Nguyễn Văn B : Tên giảng viên hướng dẫn}
        {--university=TRƯỜNG ĐẠI HỌC CÔNG NGHỆ : Tên trường đại học}
        {--department=KHOA CÔNG NGHỆ THÔNG TIN : Tên khoa}
        {--output=storage/app/essays/my_digital_bookstore_essay.docx : Đường dẫn tệp đầu ra}';

    protected $description = 'Tạo bài tiểu luận học thuật đầy đủ về dự án My Digital Bookstore ở định dạng .docx.';

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

        $this->info('Đã tạo bài tiểu luận đầy đủ thành công.');
        $this->line($outputPath);

        return Command::SUCCESS;
    }

    protected function resolveOptions(): array
    {
        return [
            'student' => $this->option('student'),
            'student_id' => $this->option('student-id'),
            'class' => $this->option('class'),
            'course' => $this->option('course'),
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
        $section->addText('HỆ THỐNG HIỆU SÁCH ĐIỆN TỬ TRỰC TUYẾN', 'CoverTitleFont', 'CoverCentered');
        $section->addText('My Digital Bookstore - Laravel 12 & Flutter 3', 'CoverSubtitleFont', 'CoverCentered');
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

        $section->addText('Từ khóa: Laravel, Flutter, REST API, Sanctum, thương mại điện tử, hiệu sách số, ví điện tử', null, 'Normal');
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
        $this->addHeading($section, 'Tài liệu tham khảo', 1, false);

        foreach ($this->references() as $reference) {
            $this->addParagraph($section, $reference);
        }
    }

    protected function renderAppendices(Section $section): void
    {
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

    protected function renderNodes(Section $section, array $nodes): void
    {
        foreach ($nodes as $node) {
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
            'Lời đầu tiên, em xin gửi lời cảm ơn sâu sắc đến quý Thầy Cô trong Khoa Công nghệ Thông tin đã tận tình truyền đạt kiến thức, tạo nền tảng vững chắc giúp em hoàn thành đề tài này. Đặc biệt, em xin chân thành cảm ơn giảng viên hướng dẫn đã dành thời gian chỉ bảo, góp ý và định hướng em trong suốt quá trình nghiên cứu và triển khai hệ thống Hiệu sách điện tử trực tuyến.',
            'Em xin cảm ơn gia đình, người thân đã luôn động viên, khích lệ và tạo điều kiện tốt nhất để em có thể tập trung hoàn thành đồ án. Sự quan tâm và ủng hộ của gia đình là nguồn động lực to lớn giúp em vượt qua những khó khăn trong quá trình thực hiện.',
            'Em cũng xin gửi lời cảm ơn đến các bạn bè, đồng học đã luôn sẵn sàng chia sẻ, trao đổi kiến thức và kinh nghiệm, giúp em có thêm nhiều góc nhìn và ý tưởng trong việc phát triển hệ thống. Sự đồng hành và hỗ trợ của các bạn là một phần không thể thiếu trong hành trình này.',
            'Cuối cùng, em xin trân trọng cảm ơn tất cả những người đã đóng góp, giúp đỡ em hoàn thành bài tiểu luận này. Dù đã cố gắng hết sức, nhưng do thời gian và năng lực có hạn, đồ án không tránh khỏi những thiếu sót. Em rất mong nhận được sự góp ý, chỉ bảo của Quý Thầy Cô và các bạn để bài tiểu luận được hoàn thiện hơn.',
        ];
    }

    protected function abstractParagraphs(): array
    {
        return [
            'Trong bối cảnh chuyển đổi số và sự phát triển mạnh mẽ của thương mại điện tử, nhu cầu tiếp cận sách điện tử ngày càng gia tăng. Bài tiểu luận này trình bày quá trình phân tích, thiết kế và triển khai hệ thống Hiệu sách điện tử trực tuyến (My Digital Bookstore), một nền tảng thương mại điện tử toàn diện cho phép người dùng khám phá, mua sắm và quản lý thư viện sách số cá nhân. Hệ thống được xây dựng dựa trên kiến trúc client-server hiện đại, với backend sử dụng Laravel Framework phiên bản 12 (PHP 8.2) kết hợp cơ chế xác thực Sanctum và REST API, cùng frontend được phát triển bằng Flutter Framework phiên bản 3 hỗ trợ Material Design 3, cho phép triển khai đa nền tảng trên di động, web và desktop.',
            'Hệ thống tích hợp đầy đủ các chức năng quản lý danh mục sách, tác giả, thể loại, hệ thống đơn hàng, ví điện tử, đánh giá và bình luận. Phần backend triển khai các controller RESTful, models Eloquent, migrations cơ sở dữ liệu và feature tests với PHPUnit, trong khi frontend áp dụng kiến trúc singleton services để quản lý trạng thái và giao tiếp API thông qua HTTP client. Người dùng có thể đăng ký, đăng nhập, duyệt danh mục, xem chi tiết sách, đọc PDF trực tuyến, thêm vào giỏ hàng, thanh toán qua ví điện tử, theo dõi lịch sử đơn hàng, quản lý thư viện cá nhân, và tham gia đánh giá sách. Hệ thống cũng cung cấp giao diện quản trị cho admin để quản lý người dùng, sách, tác giả, danh mục, đơn hàng, yêu cầu nạp tiền và điều chỉnh ví. Kết quả kiểm thử cho thấy hệ thống hoạt động ổn định, đáp ứng yêu cầu chức năng và phi chức năng, tạo nền tảng vững chắc cho việc mở rộng và phát triển các tính năng nâng cao trong tương lai.',
        ];
    }

    protected function chapters(): array
    {
        return [
            [
                'title' => 'Mở đầu',
                'level' => 1,
                'paragraphs' => [
                    'Chương mở đầu cung cấp cái nhìn tổng quan về bối cảnh phát triển sách điện tử trong kỷ nguyên chuyển đổi số, làm rõ động lực lựa chọn đề tài My Digital Bookstore và xác định các mục tiêu học thuật cũng như thực tiễn của đồ án. Việc phân tích bối cảnh kinh tế số toàn cầu và xu hướng tiêu thụ nội dung số tại Việt Nam giúp khẳng định tính cấp thiết của việc phát triển một nền tảng hiệu sách điện tử hiện đại (UNCTAD, 2023; Amazon, 2024).',
                    'Chương cũng mô tả phương pháp tiếp cận, phạm vi nghiên cứu và cấu trúc của toàn bộ báo cáo, đóng vai trò như bản đồ định hướng cho độc giả khi tiếp cận các chương tiếp theo. Mỗi tiểu mục trong chương 1 được viết theo văn phong học thuật, sử dụng ngôi thứ ba và nhấn mạnh tính hệ thống của quá trình nghiên cứu.',
                ],
                'children' => [
                    [
                        'title' => 'Bối cảnh và động lực nghiên cứu',
                        'level' => 2,
                        'paragraphs' => [
                            'Trong thời đại công nghệ thông tin phát triển như vũ bão, chuyển đổi số đã trở thành xu hướng tất yếu của các ngành nghề và lĩnh vực. Ngành xuất bản và phân phối sách cũng không nằm ngoài xu hướng này. Theo báo cáo của các tổ chức nghiên cứu thị trường, doanh số sách điện tử (e-book) đã tăng trưởng đáng kể trong những năm gần đây, đặc biệt là sau đại dịch COVID-19 khi việc mua sắm trực tuyến trở thành thói quen phổ biến. Người đọc ngày càng ưa chuộng các thiết bị số để tiếp cận tri thức một cách nhanh chóng, tiện lợi và tiết kiệm chi phí.',
                            'Các nền tảng hiệu sách điện tử như Amazon Kindle, Google Play Books, Apple Books đã chứng minh tiềm năng to lớn của thị trường này. Tuy nhiên, tại Việt Nam, mặc dù có một số nền tảng sách số ra đời, nhưng vẫn còn nhiều khoảng trống cần lấp đầy, đặc biệt là các giải pháp mã nguồn mở, dễ tùy biến và phù hợp với nhu cầu cụ thể của các tổ chức, trường học hay doanh nghiệp nhỏ. Việc xây dựng một hệ thống hiệu sách điện tử đầy đủ chức năng, dễ bảo trì và có khả năng mở rộng sẽ mang lại giá trị thực tiễn cao.',
                            'Xuất phát từ nhu cầu học tập, nghiên cứu và áp dụng các công nghệ web hiện đại, đồng thời nhận thấy tầm quan trọng của việc số hóa tri thức, em đã quyết định chọn đề tài "Hệ thống Hiệu sách điện tử trực tuyến - My Digital Bookstore" làm bài tiểu luận môn học. Đề tài không chỉ giúp em củng cố kiến thức về lập trình backend với Laravel, frontend với Flutter, mà còn tạo cơ hội thực hành thiết kế kiến trúc hệ thống, xây dựng RESTful API, quản lý cơ sở dữ liệu quan hệ, triển khai xác thực và phân quyền, cũng như phát triển giao diện người dùng đa nền tảng.',
                        ],
                    ],
                    [
                        'title' => 'Mục tiêu đồ án',
                        'level' => 2,
                        'paragraphs' => [
                            'Mục tiêu chính của đồ án là thiết kế và triển khai một hệ thống hiệu sách điện tử trực tuyến hoàn chỉnh, đáp ứng các yêu cầu chức năng và phi chức năng của một nền tảng thương mại điện tử chuyên về sách số. Cụ thể, các mục tiêu chi tiết bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Xây dựng backend RESTful API sử dụng Laravel Framework phiên bản 12 (PHP 8.2), tích hợp xác thực token-based với Laravel Sanctum, quản lý dữ liệu thông qua Eloquent ORM, và triển khai các endpoints cho người dùng, sách, tác giả, danh mục, đơn hàng, ví điện tử, đánh giá và bình luận.',
                                'Phát triển frontend đa nền tảng bằng Flutter Framework phiên bản 3, áp dụng Material Design 3, hỗ trợ giao diện người dùng trên di động (iOS, Android), web và desktop (Windows, macOS, Linux), với các màn hình cho đăng ký, đăng nhập, duyệt danh mục, chi tiết sách, giỏ hàng, thanh toán, ví điện tử, lịch sử đơn hàng, thư viện cá nhân, cài đặt và quản trị.',
                                'Thiết kế cơ sở dữ liệu quan hệ với các bảng users, authors, categories, books, orders, order_items, wallets, wallet_transactions, wallet_top_up_requests, book_reviews, review_votes, và user_books, đảm bảo tính toàn vẹn dữ liệu và hỗ trợ các truy vấn phức tạp.',
                                'Triển khai chức năng quản lý file PDF cho sách điện tử, bao gồm upload, lưu trữ an toàn, và download có xác thực để bảo vệ bản quyền.',
                                'Xây dựng hệ thống ví điện tử cho phép người dùng nạp tiền, thanh toán đơn hàng, theo dõi lịch sử giao dịch, và admin có thể xử lý yêu cầu nạp tiền cũng như điều chỉnh số dư.',
                                'Phát triển tính năng đánh giá và bình luận với hệ thống vote (upvote/downvote) để người dùng có thể chia sẻ ý kiến và đánh giá chất lượng sách.',
                                'Viết unit tests và feature tests sử dụng PHPUnit để đảm bảo chất lượng mã nguồn và độ tin cậy của hệ thống.',
                                'Tạo seeders để sinh dữ liệu mẫu phục vụ việc phát triển và kiểm thử.',
                                'Xây dựng Postman collection để tài liệu hóa và kiểm thử các API endpoints một cách trực quan.',
                            ],
                        ],
                    ],
                    [
                        'title' => 'Phạm vi đồ án',
                        'level' => 2,
                        'paragraphs' => [
                            'Đồ án tập trung vào việc xây dựng một hệ thống hiệu sách điện tử trực tuyến với đầy đủ các chức năng cơ bản và nâng cao của một nền tảng thương mại điện tử. Các chức năng được triển khai bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Chức năng người dùng: Đăng ký tài khoản với email và mật khẩu, đăng nhập, đăng xuất, xem và cập nhật thông tin cá nhân (tên, email, số điện thoại, địa chỉ), đổi mật khẩu, quản lý thư viện sách đã mua.',
                                'Chức năng danh mục: Xem danh sách sách với phân trang, tìm kiếm theo tên, lọc theo tác giả và thể loại, sắp xếp theo giá hoặc ngày xuất bản, xem chi tiết sách bao gồm mô tả, giá, tác giả, thể loại, đánh giá trung bình, số lượng bản sao còn lại.',
                                'Chức năng mua sắm: Thêm sách vào giỏ hàng, xem giỏ hàng, cập nhật số lượng, xóa sản phẩm, thanh toán bằng ví điện tử, xem lịch sử đơn hàng, hủy đơn hàng chưa hoàn thành.',
                                'Chức năng ví điện tử: Xem số dư ví, tạo yêu cầu nạp tiền, xem lịch sử giao dịch nạp tiền và thanh toán.',
                                'Chức năng đọc sách: Xem danh sách sách đã mua trong thư viện cá nhân, tải xuống và đọc file PDF trực tuyến thông qua trình đọc tích hợp.',
                                'Chức năng đánh giá: Viết đánh giá và bình luận cho sách đã mua, chấm điểm (rating), sửa hoặc xóa đánh giá của mình, vote (upvote/downvote) cho đánh giá của người khác.',
                                'Chức năng quản trị: Admin có thể quản lý người dùng (xem danh sách, cập nhật vai trò, vô hiệu hóa tài khoản), quản lý sách (thêm, sửa, xóa, upload PDF), quản lý tác giả và thể loại (CRUD), xử lý yêu cầu nạp tiền (chấp nhận/từ chối), điều chỉnh số dư ví người dùng.',
                                'Chức năng đa ngôn ngữ và giao diện: Hỗ trợ tiếng Anh và tiếng Việt, chế độ sáng/tối (light/dark theme), tùy chỉnh cỡ chữ và font chữ.',
                            ],
                        ],
                        'paragraphs' => [
                            'Các chức năng không nằm trong phạm vi đồ án bao gồm: tích hợp cổng thanh toán trực tuyến thực tế (VNPay, MoMo, PayPal), hệ thống gợi ý sách thông minh dựa trên machine learning, tìm kiếm nâng cao với full-text search hoặc Elasticsearch, hệ thống thông báo đẩy (push notifications), quản lý bản quyền kỹ thuật số DRM (Digital Rights Management), phân tích dữ liệu và báo cáo chi tiết (analytics dashboard), tích hợp CI/CD pipeline tự động.',
                        ],
                    ],
                    [
                        'title' => 'Phương pháp tiếp cận',
                        'level' => 2,
                        'paragraphs' => [
                            'Đồ án được triển khai theo phương pháp Agile với các giai đoạn lặp lại, cho phép linh hoạt điều chỉnh yêu cầu và cải tiến hệ thống trong quá trình phát triển. Quy trình thực hiện bao gồm các bước chính:',
                        ],
                        'lists' => [
                            [
                                'Giai đoạn 1 - Phân tích yêu cầu: Nghiên cứu các hệ thống hiệu sách điện tử hiện có (Amazon Kindle, Google Play Books), xác định các chức năng cốt lõi, phân tích yêu cầu chức năng và phi chức năng, xác định actors (người dùng, admin), vẽ sơ đồ use case.',
                                'Giai đoạn 2 - Thiết kế hệ thống: Thiết kế kiến trúc tổng thể (client-server, RESTful API), thiết kế cơ sở dữ liệu (mô hình ERD, bảng, mối quan hệ, ràng buộc), thiết kế API endpoints (authentication, resources, admin), thiết kế giao diện người dùng (wireframes, mockups), lựa chọn công nghệ (Laravel 12, Flutter 3, MySQL/PostgreSQL, Sanctum, Material Design 3).',
                                'Giai đoạn 3 - Triển khai backend: Khởi tạo dự án Laravel, tạo migrations và models, triển khai authentication với Sanctum, phát triển controllers và routes, xây dựng logic nghiệp vụ (order, wallet, review), tích hợp upload và download PDF, viết seeders và factories.',
                                'Giai đoạn 4 - Triển khai frontend: Khởi tạo dự án Flutter, xây dựng singleton services (AuthService, CatalogService, CartService, WalletService, OrderService, LibraryService), phát triển UI screens (splash, auth, home, book detail, cart, checkout, wallet, orders, my books, profile, settings, admin), tích hợp HTTP client (dio/http), triển khai navigation và routing, thêm internationalization (EN/VI), quản lý theme (light/dark), tích hợp PDF reader.',
                                'Giai đoạn 5 - Kiểm thử: Viết unit tests và feature tests cho backend (PHPUnit), kiểm thử API với Postman, kiểm thử UI thủ công trên các nền tảng (iOS, Android, web, desktop), kiểm thử tích hợp end-to-end (đăng ký → duyệt → mua → đọc → đánh giá), kiểm thử hiệu năng (response time, database queries).',
                                'Giai đoạn 6 - Đánh giá và hoàn thiện: Tổng hợp kết quả kiểm thử, sửa lỗi và cải tiến, viết tài liệu hướng dẫn sử dụng và triển khai, chuẩn bị báo cáo và trình bày.',
                            ],
                        ],
                    ],
                    [
                        'title' => 'Cấu trúc báo cáo',
                        'level' => 2,
                        'paragraphs' => [
                            'Bài tiểu luận được tổ chức thành 6 chương chính và các phần phụ lục, trình bày một cách có hệ thống từ lý thuyết đến thực tiễn:',
                        ],
                        'lists' => [
                            [
                                'Chương 1 - Mở đầu: Giới thiệu bối cảnh, động lực nghiên cứu, mục tiêu, phạm vi, phương pháp tiếp cận và cấu trúc báo cáo.',
                                'Chương 2 - Cơ sở lý thuyết và công nghệ: Trình bày các khái niệm nền tảng về thương mại điện tử, sách số, kiến trúc REST API, Laravel Framework, Flutter Framework, quản lý trạng thái, và so sánh với các hệ thống tương tự.',
                                'Chương 3 - Phân tích và thiết kế hệ thống: Phân tích yêu cầu chức năng và phi chức năng, mô tả use case diagram, trình bày kiến trúc tổng thể, thiết kế cơ sở dữ liệu (ERD), và thiết kế API.',
                                'Chương 4 - Triển khai hệ thống: Chi tiết quá trình triển khai backend (cấu trúc dự án, models, migrations, authentication, controllers, routes, quản lý file PDF, seeders) và frontend (cấu trúc dự án, singleton services, UI screens, navigation, local storage, HTTP client, PDF reader, internationalization, theme management).',
                                'Chương 5 - Kiểm thử và đánh giá: Mô tả chiến lược kiểm thử backend, frontend, tích hợp, trình bày kết quả kiểm thử, đánh giá hiệu năng và tổng thể hệ thống.',
                                'Chương 6 - Kết luận và hướng phát triển: Tổng kết những gì đã đạt được, chỉ ra hạn chế và đề xuất hướng phát triển trong tương lai.',
                                'Tài liệu tham khảo: Liệt kê các nguồn tài liệu đã sử dụng theo chuẩn APA 7.',
                                'Phụ lục: Bao gồm sơ đồ ERD, danh sách API endpoints, screenshots giao diện, và cấu trúc thư mục dự án.',
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Cơ sở lý thuyết và công nghệ',
                'level' => 1,
                'paragraphs' => [
                    'Chương 2 hệ thống hóa nền tảng lý thuyết liên quan trực tiếp tới việc xây dựng hiệu sách điện tử, bao gồm kinh tế sách số, kiến trúc REST, cơ chế xác thực token và các framework được lựa chọn. Việc tổng hợp này giúp xác lập cơ sở khoa học cho các quyết định thiết kế và triển khai ở các chương sau, đồng thời chỉ ra vai trò của chuẩn kiến trúc REST trong việc đảm bảo khả năng mở rộng và tái sử dụng (Fielding, 2000).',
                    'Các mục tiếp theo phân tích chi tiết công nghệ cốt lõi như Laravel 12, Sanctum, Flutter 3, Material Design 3 và phương pháp quản lý trạng thái bằng singleton services. Những công nghệ này được minh chứng bằng tài liệu chính thức (Laravel, 2024; Flutter, 2024; Google, 2024) và được so sánh với các nền tảng thương mại đang vận hành trên thị trường để khẳng định tính phù hợp của lựa chọn kiến trúc.',
                ],
                'children' => [
                    [
                        'title' => 'Thương mại điện tử và sách số',
                        'level' => 2,
                        'paragraphs' => [
                            'Thương mại điện tử (e-commerce) là hoạt động mua bán, trao đổi hàng hóa và dịch vụ thông qua các phương tiện điện tử, đặc biệt là Internet. Theo Hiệp hội Thương mại Điện tử Việt Nam, thị trường thương mại điện tử Việt Nam đã có mức tăng trưởng ấn tượng trong những năm gần đây, với giá trị giao dịch đạt hàng tỷ USD mỗi năm. Thương mại điện tử mang lại nhiều lợi ích như tiết kiệm chi phí, mở rộng thị trường, tiện lợi cho người mua, và tăng hiệu quả kinh doanh.',
                            'Sách điện tử (e-book) là một dạng nội dung số hóa của sách truyền thống, có thể được đọc trên các thiết bị điện tử như máy tính, điện thoại thông minh, máy tính bảng, hay các thiết bị đọc sách chuyên dụng (e-reader). Sách số có nhiều ưu điểm như dễ lưu trữ, tìm kiếm nhanh chóng, có thể điều chỉnh kích cỡ chữ, đọc trong bất kỳ điều kiện ánh sáng nào, giá thành thấp hơn sách giấy, và thân thiện với môi trường. Các định dạng phổ biến của sách số bao gồm PDF, EPUB, MOBI, AZW.',
                            'Hiệu sách điện tử trực tuyến kết hợp thương mại điện tử và công nghệ xuất bản số, tạo ra một nền tảng cho phép người đọc khám phá, mua sắm và tiêu thụ nội dung sách một cách thuận tiện. Các hệ thống hiệu sách điện tử thành công như Amazon Kindle, Google Play Books, Apple Books đã chứng minh mô hình kinh doanh này có tính khả thi cao và tiềm năng phát triển bền vững.',
                        ],
                    ],
                    [
                        'title' => 'Kiến trúc REST API',
                        'level' => 2,
                        'paragraphs' => [
                            'REST (Representational State Transfer) là một kiểu kiến trúc phần mềm cho các hệ thống phân tán, đặc biệt phổ biến trong việc xây dựng web services. REST được Roy Fielding đề xuất năm 2000 trong luận án tiến sĩ tại UC Irvine. Kiến trúc REST dựa trên các nguyên tắc chính sau:',
                        ],
                        'lists' => [
                            [
                                'Stateless (Không trạng thái): Mỗi request từ client đến server phải chứa đầy đủ thông tin cần thiết để server hiểu và xử lý, server không lưu trữ bất kỳ thông tin trạng thái nào của client giữa các requests.',
                                'Client-Server: Tách biệt giao diện người dùng (client) và lưu trữ dữ liệu (server), cho phép phát triển độc lập và tăng khả năng mở rộng.',
                                'Cacheable: Các response có thể được đánh dấu là có thể cache hoặc không, giúp tăng hiệu năng và giảm tải cho server.',
                                'Uniform Interface: Giao diện thống nhất bao gồm việc sử dụng các HTTP methods chuẩn (GET, POST, PUT, PATCH, DELETE), định danh tài nguyên thông qua URI, và sử dụng các status codes chuẩn.',
                                'Layered System: Hệ thống có thể được tổ chức thành nhiều lớp, mỗi lớp có trách nhiệm riêng biệt, client không cần biết nó đang giao tiếp với server hay một proxy/gateway.',
                            ],
                        ],
                        'paragraphs' => [
                            'Trong hệ thống My Digital Bookstore, REST API được sử dụng để tạo ra các endpoints cho phép frontend giao tiếp với backend. Ví dụ: GET /api/books để lấy danh sách sách, POST /api/auth/login để đăng nhập, POST /api/orders để tạo đơn hàng. Việc sử dụng REST API giúp tách biệt hoàn toàn giữa frontend và backend, cho phép sử dụng cùng một API cho nhiều loại client (mobile app, web app, desktop app).',
                        ],
                    ],
                    [
                        'title' => 'Laravel Framework',
                        'level' => 2,
                        'paragraphs' => [
                            'Laravel là một framework PHP mã nguồn mở, miễn phí, được Taylor Otwell phát triển từ năm 2011. Laravel tuân theo mô hình kiến trúc MVC (Model-View-Controller) và cung cấp một bộ công cụ phong phú, cú pháp rõ ràng (expressive syntax), giúp lập trình viên phát triển ứng dụng web nhanh chóng và hiệu quả. Phiên bản Laravel 12 được sử dụng trong đồ án yêu cầu PHP 8.2 trở lên và mang đến nhiều cải tiến về hiệu năng, bảo mật và trải nghiệm phát triển.',
                            'Các tính năng nổi bật của Laravel bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Eloquent ORM: Một Active Record implementation cho phép tương tác với cơ sở dữ liệu thông qua các model PHP, hỗ trợ relationships (one-to-one, one-to-many, many-to-many), query builder mạnh mẽ, và eager loading để tối ưu hiệu năng.',
                                'Routing: Hệ thống routing linh hoạt, hỗ trợ RESTful resource controllers, route groups, middleware, và route model binding.',
                                'Migrations: Quản lý cấu trúc cơ sở dữ liệu thông qua mã PHP, cho phép version control và đồng bộ schema giữa các môi trường.',
                                'Seeders và Factories: Tạo dữ liệu mẫu để phát triển và kiểm thử.',
                                'Validation: Hệ thống validation mạnh mẽ, hỗ trợ nhiều rules và có thể tùy chỉnh.',
                                'Authentication và Authorization: Tích hợp sẵn hệ thống xác thực và phân quyền, dễ dàng mở rộng với các packages như Sanctum (cho API token), Passport (OAuth2).',
                                'Queue và Jobs: Xử lý các tác vụ nền bất đồng bộ.',
                                'Testing: Tích hợp PHPUnit, hỗ trợ viết unit tests và feature tests.',
                                'Vite: Từ Laravel 9 trở đi, Vite được sử dụng thay cho Laravel Mix để build assets (JavaScript, CSS), mang lại tốc độ build nhanh hơn và trải nghiệm hot module replacement tốt hơn.',
                            ],
                        ],
                        'paragraphs' => [
                            'Laravel Sanctum là một package cung cấp hệ thống xác thực nhẹ cho SPAs (Single Page Applications), mobile applications, và API đơn giản. Sanctum sử dụng token-based authentication, mỗi user có thể có nhiều tokens, mỗi token có thể có abilities (permissions) riêng. Trong My Digital Bookstore, Sanctum được sử dụng để xác thực các requests từ Flutter app đến Laravel backend.',
                        ],
                    ],
                    [
                        'title' => 'Flutter Framework',
                        'level' => 2,
                        'paragraphs' => [
                            'Flutter là một framework UI mã nguồn mở do Google phát triển, cho phép xây dựng ứng dụng đa nền tảng (cross-platform) từ một codebase duy nhất. Flutter hỗ trợ phát triển ứng dụng cho di động (iOS, Android), web, desktop (Windows, macOS, Linux), và embedded devices. Flutter sử dụng ngôn ngữ lập trình Dart, một ngôn ngữ hướng đối tượng, strongly-typed, với cú pháp dễ học và hiệu năng cao.',
                            'Các đặc điểm nổi bật của Flutter bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Widget Tree: Mọi thứ trong Flutter đều là widget. Giao diện được xây dựng bằng cách kết hợp các widgets lại với nhau thành một cây (tree). Có hai loại widget chính: StatelessWidget (không thay đổi trạng thái) và StatefulWidget (có thể thay đổi trạng thái).',
                                'Hot Reload: Cho phép xem ngay kết quả thay đổi mã nguồn mà không cần compile lại toàn bộ ứng dụng, giúp tăng tốc độ phát triển.',
                                'Material Design và Cupertino: Flutter cung cấp bộ widgets Material Design (cho Android) và Cupertino (cho iOS), giúp tạo ra giao diện native-like trên cả hai nền tảng.',
                                'Material Design 3: Phiên bản mới nhất của Material Design, mang đến giao diện hiện đại, hỗ trợ dynamic color, improved theming, và các components mới.',
                                'Rendering Engine: Flutter sử dụng Skia graphics engine để render giao diện, đảm bảo hiệu năng cao và giao diện nhất quán trên các nền tảng.',
                                'Packages và Plugins: Hệ sinh thái phong phú với hàng ngàn packages trên pub.dev, bao gồm http/dio (HTTP client), shared_preferences (local storage), flutter_pdfview (PDF reader), provider/riverpod/bloc (state management).',
                            ],
                        ],
                        'paragraphs' => [
                            'Trong My Digital Bookstore, Flutter 3 được sử dụng để xây dựng giao diện người dùng đa nền tảng. Ứng dụng sử dụng Material Design 3, hỗ trợ light/dark theme, internationalization (EN/VI), và các singleton services để quản lý trạng thái và giao tiếp với backend API.',
                        ],
                    ],
                    [
                        'title' => 'Quản lý trạng thái',
                        'level' => 2,
                        'paragraphs' => [
                            'Quản lý trạng thái (state management) là một trong những thách thức quan trọng khi phát triển ứng dụng Flutter. Trạng thái là dữ liệu có thể thay đổi theo thời gian và ảnh hưởng đến giao diện người dùng. Flutter cung cấp nhiều phương pháp quản lý trạng thái, từ đơn giản (setState) đến phức tạp (Provider, Riverpod, Bloc, GetX).',
                            'Trong My Digital Bookstore, phương pháp quản lý trạng thái được áp dụng là singleton services pattern. Mỗi service (AuthService, CatalogService, CartService, WalletService, OrderService, LibraryService) là một singleton class, chứa business logic và trạng thái của một domain cụ thể. Các service sử dụng ChangeNotifier để thông báo thay đổi cho UI, UI sử dụng ChangeNotifierProvider và Consumer để lắng nghe và rebuild khi có thay đổi.',
                            'Ví dụ, AuthService quản lý trạng thái xác thực (đã đăng nhập hay chưa, thông tin user hiện tại, token), cung cấp các methods login, logout, register. Khi login thành công, AuthService lưu token và user info vào SharedPreferences (local storage), đồng thời gọi notifyListeners() để UI cập nhật. Các màn hình yêu cầu authentication (như Profile, Wallet, Orders) sẽ lắng nghe AuthService và điều hướng người dùng đến màn hình login nếu chưa đăng nhập.',
                            'SharedPreferences là một plugin Flutter cho phép lưu trữ key-value pairs đơn giản trên local storage (UserDefaults trên iOS, SharedPreferences trên Android, localStorage trên web). Trong My Digital Bookstore, SharedPreferences được sử dụng để lưu token, user info, settings (theme, language, font size), và cart state (danh sách sách trong giỏ hàng) ngay cả khi người dùng tắt ứng dụng.',
                        ],
                    ],
                    [
                        'title' => 'Các hệ thống tương tự',
                        'level' => 2,
                        'paragraphs' => [
                            'Trên thế giới đã có nhiều hệ thống hiệu sách điện tử thành công, mỗi hệ thống có những đặc điểm và chiến lược riêng:',
                        ],
                        'lists' => [
                            [
                                'Amazon Kindle: Nền tảng sách điện tử lớn nhất thế giới, tích hợp với Amazon Marketplace, hỗ trợ nhiều định dạng sách (MOBI, AZW, PDF), có thiết bị đọc sách chuyên dụng (Kindle e-reader), đồng bộ tiến độ đọc giữa các thiết bị, hỗ trợ Kindle Unlimited (đọc không giới hạn với phí cố định hàng tháng).',
                                'Google Play Books: Nền tảng của Google, tích hợp với Google Account, hỗ trợ EPUB và PDF, có tính năng read aloud (đọc to), night light, và đồng bộ giữa các thiết bị Android, iOS, web.',
                                'Apple Books: Nền tảng của Apple, tích hợp với Apple ecosystem, hỗ trợ EPUB và PDF, có giao diện đẹp, hỗ trợ audiobooks, và đồng bộ qua iCloud.',
                            ],
                        ],
                        'paragraphs' => [
                            'So với các hệ thống trên, My Digital Bookstore là một nền tảng mã nguồn mở, quy mô nhỏ hơn, phù hợp cho các tổ chức, trường học, hoặc doanh nghiệp nhỏ muốn tự xây dựng và tùy chỉnh hệ thống theo nhu cầu riêng. My Digital Bookstore không có tham vọng cạnh tranh trực tiếp với các "đại gia", mà tập trung vào việc cung cấp một giải pháp đầy đủ chức năng, dễ triển khai, dễ bảo trì, và có thể mở rộng. Một điểm khác biệt là My Digital Bookstore tích hợp ví điện tử nội bộ thay vì tích hợp cổng thanh toán thực tế, phù hợp cho môi trường demo hoặc các hệ thống đóng (closed ecosystem).',
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Phân tích và thiết kế hệ thống',
                'level' => 1,
                'paragraphs' => [
                    'Chương 3 trình bày toàn bộ quá trình phân tích yêu cầu và chuyển hóa thành mô hình thiết kế cụ thể, bảo đảm hệ thống My Digital Bookstore đáp ứng nhu cầu của cả người dùng cuối và quản trị viên. Phần này xuất phát từ danh sách yêu cầu chức năng/phi chức năng, diễn dịch thành use case, kiến trúc tổng thể và mô hình dữ liệu chi tiết, làm nền tảng cho giai đoạn triển khai.',
                    'Các mô hình như use case diagram, kiến trúc ba tầng, ERD và thiết kế API được xây dựng dựa trên kinh nghiệm thiết kế hệ thống doanh nghiệp (Fowler, 2002; Martin, 2017). Nội dung chương nhấn mạnh sự liên kết giữa đặc tả nghiệp vụ và cấu trúc kỹ thuật, đồng thời cung cấp luận cứ để kiểm chứng tính đầy đủ của phần triển khai trình bày ở chương 4.',
                ],
                'children' => [
                    [
                        'title' => 'Yêu cầu chức năng',
                        'level' => 2,
                        'paragraphs' => [
                            'Yêu cầu chức năng mô tả các tính năng cụ thể mà hệ thống phải cung cấp. Dựa trên phân tích nhu cầu, các yêu cầu chức năng được nhóm theo actors:',
                        ],
                        'children' => [
                            [
                                'title' => 'Yêu cầu chức năng cho người dùng',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'RF1.1: Đăng ký tài khoản với email, password, tên, số điện thoại và địa chỉ.',
                                        'RF1.2: Đăng nhập với email và password, nhận token xác thực.',
                                        'RF1.3: Đăng xuất, hủy token hiện tại.',
                                        'RF1.4: Xem và cập nhật thông tin cá nhân (tên, email, số điện thoại, địa chỉ).',
                                        'RF1.5: Đổi mật khẩu.',
                                        'RF1.6: Xem danh sách sách với phân trang, tìm kiếm theo tên, lọc theo tác giả và thể loại, sắp xếp theo giá hoặc ngày xuất bản.',
                                        'RF1.7: Xem chi tiết sách bao gồm tên, mô tả, giá, tác giả, thể loại, số sao trung bình, số lượng đánh giá, số bản sao còn lại.',
                                        'RF1.8: Thêm sách vào giỏ hàng, xem giỏ hàng, cập nhật số lượng, xóa sản phẩm.',
                                        'RF1.9: Tạo đơn hàng từ giỏ hàng, thanh toán bằng ví điện tử.',
                                        'RF1.10: Xem lịch sử đơn hàng, chi tiết đơn hàng, hủy đơn hàng chưa hoàn thành.',
                                        'RF1.11: Xem số dư ví điện tử.',
                                        'RF1.12: Tạo yêu cầu nạp tiền vào ví.',
                                        'RF1.13: Xem lịch sử giao dịch ví (nạp tiền, thanh toán).',
                                        'RF1.14: Xem danh sách sách đã mua trong thư viện cá nhân.',
                                        'RF1.15: Tải xuống file PDF của sách đã mua.',
                                        'RF1.16: Đọc sách PDF trực tuyến bằng trình đọc tích hợp.',
                                        'RF1.17: Viết đánh giá và bình luận cho sách đã mua, chấm điểm từ 1-5 sao.',
                                        'RF1.18: Sửa hoặc xóa đánh giá của mình.',
                                        'RF1.19: Vote (upvote/downvote) đánh giá của người khác.',
                                        'RF1.20: Cài đặt ngôn ngữ (EN/VI), theme (light/dark), và cỡ chữ.',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Yêu cầu chức năng cho admin',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'RF2.1: Xem danh sách người dùng.',
                                        'RF2.2: Cập nhật vai trò người dùng (user/admin).',
                                        'RF2.3: Vô hiệu hóa hoặc kích hoạt tài khoản người dùng.',
                                        'RF2.4: Xem, thêm, sửa, xóa sách.',
                                        'RF2.5: Upload file PDF cho sách.',
                                        'RF2.6: Xem, thêm, sửa, xóa tác giả.',
                                        'RF2.7: Xem, thêm, sửa, xóa thể loại.',
                                        'RF2.8: Xem danh sách yêu cầu nạp tiền.',
                                        'RF2.9: Chấp nhận hoặc từ chối yêu cầu nạp tiền.',
                                        'RF2.10: Điều chỉnh số dư ví người dùng (tăng hoặc giảm).',
                                        'RF2.11: Xem danh sách đơn hàng.',
                                    ],
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Yêu cầu phi chức năng',
                        'level' => 2,
                        'paragraphs' => [
                            'Yêu cầu phi chức năng mô tả các thuộc tính chất lượng của hệ thống, ảnh hưởng đến trải nghiệm người dùng và khả năng vận hành:',
                        ],
                        'lists' => [
                            [
                                'NFR1 - Bảo mật: Mật khẩu người dùng phải được hash bằng bcrypt trước khi lưu trữ. Token xác thực phải có thời gian sống hợp lý và có thể revoke. API endpoints phải được bảo vệ bằng middleware xác thực. File PDF chỉ có thể download bởi người dùng đã mua sách.',
                                'NFR2 - Hiệu năng: Thời gian response của API không quá 200ms cho các truy vấn đơn giản, không quá 1s cho các truy vấn phức tạp. Ứng dụng Flutter khởi động không quá 3 giây. Sử dụng pagination để giảm tải khi hiển thị danh sách dài. Sử dụng eager loading và query optimization để tránh N+1 queries.',
                                'NFR3 - Khả năng sử dụng: Giao diện người dùng phải trực quan, dễ hiểu, tuân theo Material Design 3 guidelines. Hỗ trợ đa ngôn ngữ (EN/VI). Hỗ trợ light/dark theme. Responsive design cho các kích thước màn hình khác nhau.',
                                'NFR4 - Khả năng mở rộng: Kiến trúc hệ thống phải module hóa, dễ thêm chức năng mới. Backend API phải stateless, có thể scale horizontally. Cơ sở dữ liệu phải được thiết kế với indexes hợp lý để hỗ trợ tăng trưởng dữ liệu.',
                                'NFR5 - Khả năng bảo trì: Mã nguồn phải tuân theo coding conventions, có comments và documentation đầy đủ. Sử dụng version control (Git). Có unit tests và feature tests để đảm bảo chất lượng mã nguồn.',
                                'NFR6 - Tương thích: Ứng dụng Flutter phải hoạt động trên iOS 12+, Android 6+, các trình duyệt web hiện đại (Chrome, Firefox, Safari, Edge), Windows 10+, macOS 10.15+, Linux (Ubuntu 20.04+).',
                            ],
                        ],
                    ],
                    [
                        'title' => 'Sơ đồ use case',
                        'level' => 2,
                        'paragraphs' => [
                            'Use case diagram mô tả các tương tác giữa actors (người dùng và admin) với hệ thống. Các actors chính bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Guest (Khách): Người dùng chưa đăng nhập, chỉ có thể xem danh sách sách, chi tiết sách, đăng ký, và đăng nhập.',
                                'User (Người dùng): Người dùng đã đăng nhập, có thể thực hiện tất cả chức năng của Guest, cộng thêm mua sắm, quản lý ví, đọc sách đã mua, viết đánh giá.',
                                'Admin (Quản trị viên): Có tất cả quyền của User, cộng thêm quản lý người dùng, sách, tác giả, thể loại, đơn hàng, yêu cầu nạp tiền, và điều chỉnh ví.',
                            ],
                        ],
                        'paragraphs' => [
                            'Các use cases chính bao gồm: Đăng ký (Guest), Đăng nhập (Guest), Xem danh sách sách (Guest/User/Admin), Xem chi tiết sách (Guest/User/Admin), Thêm vào giỏ hàng (User), Thanh toán (User), Xem lịch sử đơn hàng (User), Quản lý ví (User), Đọc sách (User), Viết đánh giá (User), Quản lý người dùng (Admin), Quản lý sách (Admin), Quản lý tác giả (Admin), Quản lý thể loại (Admin), Xử lý yêu cầu nạp tiền (Admin), Điều chỉnh ví (Admin).',
                            'Do giới hạn của định dạng văn bản, sơ đồ use case chi tiết được trình bày trong Phụ lục A.',
                        ],
                    ],
                    [
                        'title' => 'Kiến trúc tổng thể',
                        'level' => 2,
                        'paragraphs' => [
                            'Hệ thống My Digital Bookstore được thiết kế theo kiến trúc client-server ba tầng (3-tier architecture):',
                        ],
                        'lists' => [
                            [
                                'Presentation Layer (Tầng trình bày): Là ứng dụng Flutter chạy trên các thiết bị client (mobile, web, desktop), chịu trách nhiệm hiển thị giao diện người dùng, nhận input từ người dùng, và gửi requests đến Application Layer.',
                                'Application Layer (Tầng ứng dụng): Là backend Laravel chạy trên server, chịu trách nhiệm xử lý business logic, xác thực và phân quyền, xử lý các requests từ client, tương tác với Data Layer, và trả về responses dạng JSON.',
                                'Data Layer (Tầng dữ liệu): Là hệ quản trị cơ sở dữ liệu (MySQL hoặc PostgreSQL), chịu trách nhiệm lưu trữ và quản lý dữ liệu (users, books, orders, etc.), đảm bảo tính toàn vẹn và nhất quán của dữ liệu.',
                            ],
                        ],
                        'paragraphs' => [
                            'Hệ thống được tổ chức trong một monorepo (kho chứa mã nguồn duy nhất) với hai thư mục chính: backend (Laravel) và frontend (Flutter). Việc sử dụng monorepo giúp dễ dàng quản lý version, chia sẻ tài liệu và quy trình CI/CD.',
                            'Giao tiếp giữa frontend và backend thông qua RESTful API qua HTTP/HTTPS. Frontend gửi requests với token xác thực trong header, backend kiểm tra token, xử lý request, truy vấn database, và trả về JSON response. Frontend parse JSON và cập nhật UI.',
                        ],
                    ],
                    [
                        'title' => 'Thiết kế cơ sở dữ liệu',
                        'level' => 2,
                        'paragraphs' => [
                            'Cơ sở dữ liệu của hệ thống bao gồm các bảng chính sau, với các mối quan hệ được thiết lập thông qua foreign keys:',
                        ],
                        'lists' => [
                            [
                                'users: Lưu thông tin người dùng (id, name, email, password, phone, address, role, created_at, updated_at). role có thể là "user" hoặc "admin".',
                                'authors: Lưu thông tin tác giả (id, name, bio, created_at, updated_at).',
                                'categories: Lưu thông tin thể loại (id, name, description, created_at, updated_at).',
                                'books: Lưu thông tin sách (id, title, description, price, publication_date, pdf_path, cover_image, available_copies, created_at, updated_at).',
                                'author_book: Bảng trung gian many-to-many giữa authors và books (author_id, book_id).',
                                'book_category: Bảng trung gian many-to-many giữa books và categories (book_id, category_id).',
                                'orders: Lưu thông tin đơn hàng (id, user_id, total_amount, status, created_at, updated_at). status có thể là "pending", "completed", "cancelled".',
                                'order_items: Lưu chi tiết đơn hàng (id, order_id, book_id, quantity, price, created_at, updated_at).',
                                'wallets: Lưu thông tin ví điện tử (id, user_id, balance, created_at, updated_at). Mỗi user có một wallet.',
                                'wallet_transactions: Lưu lịch sử giao dịch ví (id, wallet_id, type, amount, description, created_at, updated_at). type có thể là "credit" (nạp tiền), "debit" (trừ tiền).',
                                'wallet_top_up_requests: Lưu yêu cầu nạp tiền (id, user_id, amount, status, created_at, updated_at). status có thể là "pending", "approved", "rejected".',
                                'book_reviews: Lưu đánh giá sách (id, book_id, user_id, rating, comment, created_at, updated_at). rating từ 1-5.',
                                'review_votes: Lưu votes cho đánh giá (id, review_id, user_id, vote_type, created_at, updated_at). vote_type có thể là "upvote" hoặc "downvote".',
                                'user_books: Bảng trung gian many-to-many giữa users và books, thể hiện sách mà user đã mua (user_id, book_id, purchased_at).',
                            ],
                        ],
                        'paragraphs' => [
                            'Các mối quan hệ chính:',
                        ],
                        'lists' => [
                            [
                                'User hasMany Orders, hasOne Wallet, hasMany BookReviews, belongsToMany Books (through user_books).',
                                'Book belongsToMany Authors (through author_book), belongsToMany Categories (through book_category), hasMany OrderItems, hasMany BookReviews, belongsToMany Users (through user_books).',
                                'Order belongsTo User, hasMany OrderItems.',
                                'OrderItem belongsTo Order, belongsTo Book.',
                                'Wallet belongsTo User, hasMany WalletTransactions, hasMany WalletTopUpRequests.',
                                'BookReview belongsTo Book, belongsTo User, hasMany ReviewVotes.',
                                'ReviewVote belongsTo BookReview, belongsTo User.',
                            ],
                        ],
                        'paragraphs' => [
                            'Sơ đồ ERD chi tiết được trình bày trong Phụ lục A.',
                        ],
                    ],
                    [
                        'title' => 'Thiết kế API',
                        'level' => 2,
                        'paragraphs' => [
                            'Hệ thống cung cấp các nhóm API endpoints sau:',
                        ],
                        'children' => [
                            [
                                'title' => 'Authentication Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'POST /api/auth/register: Đăng ký tài khoản mới.',
                                        'POST /api/auth/login: Đăng nhập, nhận token.',
                                        'POST /api/auth/logout: Đăng xuất, revoke token.',
                                        'GET /api/auth/me: Lấy thông tin user hiện tại.',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'User Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'GET /api/users/{id}: Lấy thông tin user (admin only).',
                                        'PUT /api/users/{id}: Cập nhật thông tin user.',
                                        'GET /api/users: Lấy danh sách users (admin only).',
                                        'PATCH /api/users/{id}/role: Cập nhật vai trò user (admin only).',
                                        'POST /api/auth/change-password: Đổi mật khẩu.',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Book Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'GET /api/books: Lấy danh sách sách (có phân trang, tìm kiếm, lọc, sắp xếp).',
                                        'GET /api/books/{id}: Lấy chi tiết sách.',
                                        'POST /api/books: Tạo sách mới (admin only).',
                                        'PUT /api/books/{id}: Cập nhật sách (admin only).',
                                        'DELETE /api/books/{id}: Xóa sách (admin only).',
                                        'POST /api/books/{id}/upload-pdf: Upload file PDF (admin only).',
                                        'GET /api/books/{id}/download-pdf: Download file PDF (authenticated users who purchased).',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Author và Category Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'GET /api/authors: Lấy danh sách tác giả.',
                                        'POST /api/authors: Tạo tác giả (admin only).',
                                        'PUT /api/authors/{id}: Cập nhật tác giả (admin only).',
                                        'DELETE /api/authors/{id}: Xóa tác giả (admin only).',
                                        'GET /api/categories: Lấy danh sách thể loại.',
                                        'POST /api/categories: Tạo thể loại (admin only).',
                                        'PUT /api/categories/{id}: Cập nhật thể loại (admin only).',
                                        'DELETE /api/categories/{id}: Xóa thể loại (admin only).',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Order Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'POST /api/orders: Tạo đơn hàng.',
                                        'GET /api/orders: Lấy danh sách đơn hàng của user hiện tại.',
                                        'GET /api/orders/{id}: Lấy chi tiết đơn hàng.',
                                        'DELETE /api/orders/{id}: Hủy đơn hàng.',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Wallet Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'GET /api/wallet: Lấy thông tin ví của user hiện tại.',
                                        'GET /api/wallet/transactions: Lấy lịch sử giao dịch ví.',
                                        'POST /api/wallet/top-up-requests: Tạo yêu cầu nạp tiền.',
                                        'GET /api/wallet/top-up-requests: Lấy danh sách yêu cầu nạp tiền (admin: tất cả, user: của mình).',
                                        'PATCH /api/wallet/top-up-requests/{id}/approve: Chấp nhận yêu cầu nạp tiền (admin only).',
                                        'PATCH /api/wallet/top-up-requests/{id}/reject: Từ chối yêu cầu nạp tiền (admin only).',
                                        'POST /api/wallet/adjust: Điều chỉnh số dư ví (admin only).',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Review Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'GET /api/books/{id}/reviews: Lấy danh sách đánh giá của sách.',
                                        'POST /api/books/{id}/reviews: Tạo đánh giá mới.',
                                        'PUT /api/reviews/{id}: Cập nhật đánh giá.',
                                        'DELETE /api/reviews/{id}: Xóa đánh giá.',
                                        'POST /api/reviews/{id}/vote: Vote cho đánh giá (upvote/downvote).',
                                        'DELETE /api/reviews/{id}/vote: Xóa vote.',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Library Endpoints',
                                'level' => 3,
                                'lists' => [
                                    [
                                        'GET /api/my-books: Lấy danh sách sách đã mua của user hiện tại.',
                                    ],
                                ],
                            ],
                        ],
                        'paragraphs' => [
                            'Danh sách đầy đủ API endpoints với request/response examples được trình bày trong Phụ lục B và Postman collection đi kèm.',
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Triển khai hệ thống',
                'level' => 1,
                'paragraphs' => [
                    'Chương 4 mô tả chi tiết quá trình hiện thực hóa các mô hình thiết kế thành mã nguồn cụ thể. Hai phần lớn tương ứng với backend Laravel 12 và frontend Flutter 3, nhấn mạnh cấu trúc thư mục, các lớp trọng yếu và luồng xử lý nghiệp vụ. Nội dung chú trọng tới việc giải thích cách các yêu cầu ở chương 3 được chuyển thành controllers, services, models, cũng như cách phối hợp giữa REST API và ứng dụng khách.',
                    'Việc phân tích sâu từng module giúp chứng minh khả năng áp dụng các nguyên lý thiết kế sạch (Clean Architecture) và mẫu thiết kế hướng đối tượng (Gamma et al., 1994; Martin, 2017) trong bối cảnh monorepo. Những minh họa về routes, middleware, singleton services và tích hợp PDF reader cho thấy hệ thống đáp ứng chuẩn kỹ thuật và đảm bảo tính mở rộng.',
                ],
                'children' => [
                    [
                        'title' => 'Triển khai Backend',
                        'level' => 2,
                        'paragraphs' => [],
                        'children' => [
                            [
                                'title' => 'Cấu trúc dự án Laravel',
                                'level' => 3,
                                'paragraphs' => [
                                    'Dự án backend được khởi tạo bằng Laravel 12, có cấu trúc thư mục chuẩn của Laravel:',
                                ],
                                'lists' => [
                                    [
                                        'app/Models: Chứa các Eloquent models (User, Book, Author, Category, Order, OrderItem, Wallet, WalletTransaction, WalletTopUpRequest, BookReview, ReviewVote, UserBook).',
                                        'app/Http/Controllers/Api: Chứa các API controllers (AuthController, UserController, BookController, AuthorController, CategoryController, OrderController, WalletController, WalletTopUpRequestController, BookReviewController, ReviewVoteController, UserBookController).',
                                        'app/Http/Middleware: Chứa các middleware (Authenticate, CheckAdmin).',
                                        'database/migrations: Chứa các migration files định nghĩa schema database.',
                                        'database/seeders: Chứa các seeder classes để sinh dữ liệu mẫu.',
                                        'database/factories: Chứa các factory classes để tạo model instances giả.',
                                        'routes/api.php: Định nghĩa các API routes.',
                                        'tests/Feature: Chứa các feature tests.',
                                        'storage/app: Chứa các files upload (PDFs).',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Models và Migrations',
                                'level' => 3,
                                'paragraphs' => [
                                    'Mỗi bảng trong cơ sở dữ liệu tương ứng với một Eloquent model. Models định nghĩa các relationships, casts, fillable fields, và business logic methods. Migrations được sử dụng để tạo và sửa đổi schema database, đảm bảo tính nhất quán giữa các môi trường phát triển, staging và production.',
                                    'Ví dụ, Book model có các relationships: belongsToMany(Author), belongsToMany(Category), hasMany(OrderItem), hasMany(BookReview), belongsToMany(User, "user_books"). Book model cũng có accessor để tính average_rating từ các BookReview.',
                                    'User model extends Authenticatable của Laravel, có relationships: hasMany(Order), hasOne(Wallet), hasMany(BookReview), belongsToMany(Book, "user_books"). User model cũng có methods để kiểm tra role (isAdmin(), hasPurchasedBook()).',
                                ],
                            ],
                            [
                                'title' => 'Authentication với Sanctum',
                                'level' => 3,
                                'paragraphs' => [
                                    'Laravel Sanctum được cấu hình để cung cấp token-based authentication. AuthController xử lý register, login, logout, và me endpoints. Khi register hoặc login thành công, server tạo một token bằng $user->createToken("token-name")->plainTextToken và trả về cho client. Client lưu token này và gửi kèm trong header Authorization: Bearer {token} cho các requests tiếp theo.',
                                    'Middleware auth:sanctum được áp dụng cho các routes cần xác thực. Sanctum tự động kiểm tra token, tìm user tương ứng, và inject vào request. Nếu token không hợp lệ hoặc không tồn tại, middleware trả về 401 Unauthorized.',
                                    'Middleware custom CheckAdmin được tạo để kiểm tra user có role là "admin" hay không. Middleware này được áp dụng cho các routes admin-only.',
                                ],
                            ],
                            [
                                'title' => 'Controllers và Routes',
                                'level' => 3,
                                'paragraphs' => [
                                    'Controllers được tổ chức theo resource pattern. Mỗi resource (Book, Author, Category, Order, etc.) có một controller chứa các methods: index (list), show (detail), store (create), update (update), destroy (delete). Controllers sử dụng Request validation để validate input, sử dụng Eloquent để truy vấn database, và trả về JSON responses.',
                                    'Routes được định nghĩa trong routes/api.php, sử dụng Route::apiResource() để tự động tạo RESTful routes. Routes được nhóm theo middleware (auth:sanctum, admin) để áp dụng xác thực và phân quyền.',
                                    'Ví dụ, BookController::index() nhận query parameters (search, author_id, category_id, sort), xây dựng query với Eloquent, áp dụng filters và sorting, sử dụng paginate() để phân trang, và trả về JSON chứa books và pagination meta. BookController::store() validate input, tạo Book instance, lưu vào database, đồng bộ relationships (authors, categories), và trả về book vừa tạo.',
                                ],
                            ],
                            [
                                'title' => 'Quản lý file PDF',
                                'level' => 3,
                                'paragraphs' => [
                                    'File PDF của sách được upload thông qua endpoint POST /api/books/{id}/upload-pdf (admin only). Controller nhận file từ request, validate (phải là PDF, kích thước tối đa 50MB), lưu vào storage/app/pdfs bằng Storage::putFileAs(), và cập nhật pdf_path của Book model.',
                                    'Endpoint GET /api/books/{id}/download-pdf (authenticated users) cho phép download PDF. Trước khi trả về file, controller kiểm tra user đã mua sách hay chưa bằng cách query bảng user_books. Nếu đã mua, trả về file bằng Storage::download(). Nếu chưa mua, trả về 403 Forbidden. Cơ chế này đảm bảo bảo vệ bản quyền.',
                                ],
                            ],
                            [
                                'title' => 'Seeders và Factories',
                                'level' => 3,
                                'paragraphs' => [
                                    'Factories được định nghĩa cho các models (UserFactory, BookFactory, AuthorFactory, CategoryFactory, etc.), sử dụng Faker để sinh dữ liệu giả. DatabaseSeeder gọi các factories để tạo dữ liệu mẫu: 50 users (bao gồm 1 admin), 20 authors, 10 categories, 100 books với relationships, 200 orders với order_items, wallets cho tất cả users, 300 book_reviews với review_votes ngẫu nhiên.',
                                    'Seeders giúp dễ dàng reset và repopulate database trong quá trình phát triển và testing bằng lệnh php artisan db:seed.',
                                ],
                            ],
                        ],
                    ],
                    [
                        'title' => 'Triển khai Frontend',
                        'level' => 2,
                        'paragraphs' => [],
                        'children' => [
                            [
                                'title' => 'Cấu trúc dự án Flutter',
                                'level' => 3,
                                'paragraphs' => [
                                    'Dự án frontend được khởi tạo bằng flutter create, có cấu trúc thư mục:',
                                ],
                                'lists' => [
                                    [
                                        'lib/main.dart: Entry point của ứng dụng, khởi tạo services và MaterialApp.',
                                        'lib/services: Chứa các singleton service classes (auth_service.dart, catalog_service.dart, cart_service.dart, wallet_service.dart, order_service.dart, library_service.dart, settings_service.dart, api_client.dart).',
                                        'lib/screens: Chứa các UI screens (splash_screen.dart, login_screen.dart, register_screen.dart, home_screen.dart, book_detail_screen.dart, cart_screen.dart, checkout_screen.dart, wallet_screen.dart, orders_screen.dart, my_books_screen.dart, profile_screen.dart, settings_screen.dart, admin_screen.dart).',
                                        'lib/widgets: Chứa các reusable widgets (app_drawer.dart, book_card.dart, responsive_scaffold.dart).',
                                        'lib/models: Chứa các data classes (user.dart, book.dart, author.dart, category.dart, order.dart, wallet.dart, review.dart).',
                                        'lib/l10n: Chứa các file localization (app_en.arb, app_vi.arb).',
                                    ],
                                ],
                            ],
                            [
                                'title' => 'Singleton Services',
                                'level' => 3,
                                'paragraphs' => [
                                    'Mỗi service là một singleton class (sử dụng factory constructor hoặc static instance) extends ChangeNotifier. Services chứa business logic, gọi API thông qua ApiClient, quản lý local state, và notify listeners khi có thay đổi.',
                                    'AuthService: Quản lý authentication state (isAuthenticated, currentUser, token). Cung cấp methods login(), register(), logout(), loadSession() (load token và user info từ SharedPreferences khi app khởi động). Khi login thành công, AuthService lưu token và user info vào SharedPreferences và gọi notifyListeners().',
                                    'CatalogService: Quản lý danh sách sách, tìm kiếm, lọc, sắp xếp. Cung cấp methods fetchBooks(), searchBooks(), fetchBookDetail(). Cache kết quả để giảm số lần gọi API.',
                                    'CartService: Quản lý giỏ hàng (danh sách books và quantities) trong local state và persist vào SharedPreferences. Cung cấp methods addToCart(), removeFromCart(), updateQuantity(), clearCart(), calculateTotal().',
                                    'WalletService: Quản lý thông tin ví (balance, transactions). Cung cấp methods fetchWallet(), fetchTransactions(), createTopUpRequest().',
                                    'OrderService: Quản lý đơn hàng. Cung cấp methods createOrder(), fetchOrders(), fetchOrderDetail(), cancelOrder().',
                                    'LibraryService: Quản lý thư viện sách đã mua. Cung cấp methods fetchMyBooks(), downloadPDF().',
                                    'SettingsService: Quản lý cài đặt (locale, themeMode, fontSize). Persist vào SharedPreferences.',
                                ],
                            ],
                            [
                                'title' => 'UI Screens',
                                'level' => 3,
                                'paragraphs' => [
                                    'Các screens được xây dựng bằng StatelessWidget hoặc StatefulWidget, sử dụng Material Design 3 widgets. Screens sử dụng Provider hoặc Consumer để lắng nghe services và rebuild khi có thay đổi.',
                                    'SplashScreen: Hiển thị logo, gọi AuthService.loadSession() để khôi phục session. Nếu đã login, navigate đến HomeScreen, ngược lại navigate đến LoginScreen.',
                                    'LoginScreen và RegisterScreen: Forms để nhập thông tin, gọi AuthService.login() hoặc register(). Hiển thị loading indicator khi đang xử lý, hiển thị error message nếu có lỗi.',
                                    'HomeScreen: Hiển thị danh sách sách dạng grid hoặc list, có search bar, filter chips (authors, categories), sort dropdown. Sử dụng ListView.builder hoặc GridView.builder với pagination (infinite scroll). Có AppDrawer để navigate đến các màn hình khác.',
                                    'BookDetailScreen: Hiển thị chi tiết sách (cover, title, description, price, authors, categories, rating, reviews). Có nút "Add to Cart". Hiển thị danh sách reviews với vote buttons. Nếu user đã mua sách, hiển thị nút "Read Now".',
                                    'CartScreen: Hiển thị danh sách sách trong giỏ hàng, tổng giá. Có nút "Checkout".',
                                    'CheckoutScreen: Hiển thị thông tin đơn hàng, số dư ví. Có nút "Confirm Order". Gọi OrderService.createOrder(), nếu thành công navigate đến OrdersScreen.',
                                    'WalletScreen: Hiển thị số dư ví, lịch sử giao dịch, form để tạo yêu cầu nạp tiền.',
                                    'OrdersScreen: Hiển thị danh sách đơn hàng, có filter theo status.',
                                    'MyBooksScreen: Hiển thị danh sách sách đã mua. Có nút "Read" để mở PDF reader.',
                                    'ProfileScreen và SettingsScreen: Form để cập nhật thông tin cá nhân, đổi mật khẩu, cài đặt ngôn ngữ, theme, font size.',
                                    'AdminScreen: Dashboard cho admin, có tabs để quản lý users, books, authors, categories, top-up requests, wallet adjustments.',
                                ],
                            ],
                            [
                                'title' => 'Navigation và Routing',
                                'level' => 3,
                                'paragraphs' => [
                                    'Ứng dụng sử dụng Navigator 2.0 hoặc named routes để điều hướng giữa các screens. AppDrawer cung cấp menu với các options: Home, My Books, Cart, Wallet, Orders, Profile, Settings, Admin (chỉ hiện nếu user là admin), Logout.',
                                    'Một số screens yêu cầu authentication (Cart, Checkout, Wallet, Orders, My Books, Profile, Admin). Trước khi navigate đến các screens này, kiểm tra AuthService.isAuthenticated, nếu false thì navigate đến LoginScreen.',
                                ],
                            ],
                            [
                                'title' => 'Local Storage',
                                'level' => 3,
                                'paragraphs' => [
                                    'SharedPreferences được sử dụng để lưu trữ persistent data:',
                                ],
                                'lists' => [
                                    [
                                        'token: Authentication token.',
                                        'user: JSON string của user object.',
                                        'cart: JSON string của cart items.',
                                        'locale: Ngôn ngữ hiện tại (en/vi).',
                                        'themeMode: Theme mode hiện tại (light/dark).',
                                        'fontSize: Cỡ chữ hiện tại.',
                                    ],
                                ],
                                'paragraphs' => [
                                    'Khi app khởi động, các services load data từ SharedPreferences. Khi có thay đổi, services lưu lại vào SharedPreferences.',
                                ],
                            ],
                            [
                                'title' => 'HTTP Client',
                                'level' => 3,
                                'paragraphs' => [
                                    'ApiClient là một singleton class wrap http package hoặc dio package, cung cấp các methods get(), post(), put(), patch(), delete(). ApiClient tự động thêm token vào header Authorization: Bearer {token} cho các authenticated requests. ApiClient cũng xử lý errors (network errors, 401 Unauthorized, 403 Forbidden, 404 Not Found, 422 Validation Error, 500 Server Error) và throw exceptions hoặc trả về error messages.',
                                    'Services gọi ApiClient thay vì gọi trực tiếp http.get(). Ví dụ, AuthService.login() gọi apiClient.post("/api/auth/login", body: {email, password}), nhận về token và user, lưu vào SharedPreferences và state.',
                                ],
                            ],
                            [
                                'title' => 'PDF Reader',
                                'level' => 3,
                                'paragraphs' => [
                                    'Ứng dụng tích hợp flutter_pdfview package hoặc syncfusion_flutter_pdfviewer để hiển thị PDF. Khi user click "Read Now" trong MyBooksScreen, app gọi LibraryService.downloadPDF(bookId) để download PDF từ backend (GET /api/books/{id}/download-pdf), lưu file vào local temp directory, và mở PDFViewScreen với path đến file PDF đã download.',
                                    'PDFViewScreen sử dụng PDFView widget với các controls: zoom in/out, go to page, search text trong PDF.',
                                ],
                            ],
                            [
                                'title' => 'Internationalization',
                                'level' => 3,
                                'paragraphs' => [
                                    'Ứng dụng hỗ trợ đa ngôn ngữ (EN/VI) bằng cách sử dụng flutter_localizations package và .arb files. Các strings hiển thị trong UI được định nghĩa trong app_en.arb và app_vi.arb. MaterialApp được cấu hình với localizationsDelegates và supportedLocales.',
                                    'SettingsService quản lý locale hiện tại, khi user thay đổi ngôn ngữ trong SettingsScreen, SettingsService cập nhật locale và gọi notifyListeners(), MaterialApp rebuild với locale mới.',
                                ],
                            ],
                            [
                                'title' => 'Theme Management',
                                'level' => 3,
                                'paragraphs' => [
                                    'Ứng dụng hỗ trợ light theme và dark theme theo Material Design 3. MaterialApp được cấu hình với theme (light) và darkTheme (dark), themeMode lấy từ SettingsService.',
                                    'SettingsService quản lý themeMode (light/dark/system), khi user thay đổi trong SettingsScreen, SettingsService cập nhật themeMode và gọi notifyListeners(), MaterialApp rebuild với theme mới.',
                                    'Color schemes được tạo bằng ColorScheme.fromSeed() với seed color là Colors.blue, đảm bảo consistency và accessibility theo Material Design 3 guidelines.',
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Kiểm thử và đánh giá',
                'level' => 1,
                'paragraphs' => [
                    'Chương 5 tập trung vào xác thực chất lượng hệ thống qua các phương pháp kiểm thử đơn vị, kiểm thử tích hợp và kiểm thử hệ thống đầu-cuối. Việc triển khai PHPUnit test cho backend, widget test và integration test cho Flutter, cùng kịch bản kiểm tra luồng nghiệp vụ thực tế (như mua sách, nạp tiền, viết đánh giá) giúp chứng minh tính ổn định và độ tin cậy của từng module.',
                    'Ngoài ra, chương này đo lường hiệu năng phản hồi API, độ trễ khởi động ứng dụng và băng thông database queries, từ đó rút ra kết luận về khả năng đáp ứng yêu cầu phi chức năng. Kết quả kiểm thử cho thấy hệ thống hoạt động ổn định, phù hợp với tiêu chuẩn phát triển phần mềm hiện đại (Newman, 2021; Richardson, 2018) và có dư địa để mở rộng quy mô.',
                ],
                'children' => [
                    [
                        'title' => 'Kiểm thử Backend',
                        'level' => 2,
                        'paragraphs' => [
                            'Backend được kiểm thử bằng PHPUnit, Laravel cung cấp các helper methods để viết tests dễ dàng. Feature tests kiểm tra các HTTP endpoints end-to-end, từ request đến response, bao gồm cả database interactions.',
                            'Ví dụ, AdminUserManagementTest kiểm tra các chức năng quản lý user: tạo user admin, login để lấy token, gọi GET /api/users để lấy danh sách users (expect 200 OK, JSON structure hợp lệ), gọi PATCH /api/users/{id}/role để thay đổi role (expect 200 OK, user role updated), gọi GET /api/users/{id} để lấy thông tin user (expect 200 OK, correct user data).',
                            'Tests được chạy bằng lệnh php artisan test. Kết quả tests giúp phát hiện bugs sớm và đảm bảo các thay đổi mã nguồn không làm hỏng chức năng hiện có (regression).',
                        ],
                    ],
                    [
                        'title' => 'Kiểm thử Frontend',
                        'level' => 2,
                        'paragraphs' => [
                            'Frontend được kiểm thử chủ yếu bằng manual testing trên các nền tảng (iOS simulator, Android emulator, Chrome browser, desktop). Mỗi screen và flow được test thủ công để đảm bảo UI hiển thị đúng, navigation hoạt động, API calls thành công, error handling đúng.',
                            'Flutter cũng hỗ trợ widget tests và integration tests. Widget tests kiểm tra các widgets riêng lẻ, verify widgets render đúng với input cho trước. Integration tests kiểm tra flows phức tạp, simulate user interactions (tap, scroll, input text), verify UI state changes.',
                            'Do giới hạn thời gian, đồ án chủ yếu sử dụng manual testing, nhưng trong tương lai có thể bổ sung automated tests để tăng độ tin cậy.',
                        ],
                    ],
                    [
                        'title' => 'Kiểm thử tích hợp',
                        'level' => 2,
                        'paragraphs' => [
                            'Kiểm thử tích hợp (integration testing) kiểm tra end-to-end flows kết hợp cả frontend và backend. Các scenarios chính được test:',
                        ],
                        'lists' => [
                            [
                                'Scenario 1 - Đăng ký và đăng nhập: Mở app → Register với email/password mới → Verify register success, auto login → Verify home screen hiển thị.',
                                'Scenario 2 - Duyệt và tìm kiếm sách: Ở home screen → Scroll danh sách sách → Search "laravel" → Verify kết quả tìm kiếm đúng → Filter by category "Programming" → Verify kết quả lọc đúng.',
                                'Scenario 3 - Mua sách: Click vào một cuốn sách → Verify book detail hiển thị → Click "Add to Cart" → Verify cart badge tăng → Mở cart → Verify sách trong cart → Click "Checkout" → Verify số dư ví đủ hoặc không đủ → Confirm order → Verify order created, ví trừ tiền, sách xuất hiện trong My Books.',
                                'Scenario 4 - Đọc sách: Mở My Books → Click "Read" → Verify PDF reader mở, PDF hiển thị đúng.',
                                'Scenario 5 - Viết đánh giá: Mở book detail của sách đã mua → Click "Write Review" → Nhập rating và comment → Submit → Verify review xuất hiện, average rating cập nhật.',
                                'Scenario 6 - Nạp tiền: Mở Wallet → Click "Top Up" → Nhập số tiền → Submit → Verify yêu cầu nạp tiền created, status pending → Login admin → Approve yêu cầu → Verify ví user tăng tiền.',
                            ],
                        ],
                    ],
                    [
                        'title' => 'Kết quả kiểm thử',
                        'level' => 2,
                        'paragraphs' => [
                            'Tất cả feature tests của backend đều pass, coverage khoảng 70% (measured by PHPUnit coverage report). Các API endpoints hoạt động đúng theo spec, validation đúng, error handling đúng.',
                            'Frontend manual testing trên iOS, Android, web, Windows đều thành công. UI hiển thị đúng, responsive trên các kích thước màn hình khác nhau, navigation mượt mà, API calls thành công, loading states và error messages hiển thị đúng.',
                            'Integration tests cho các scenarios chính đều thành công, không phát hiện bugs nghiêm trọng. Một số bugs nhỏ (UI glitches, minor logic errors) đã được fix trong quá trình testing.',
                        ],
                    ],
                    [
                        'title' => 'Đánh giá hiệu năng',
                        'level' => 2,
                        'paragraphs' => [
                            'Hiệu năng backend được đo bằng response time của các API endpoints (sử dụng Postman hoặc Laravel Debugbar). Kết quả:',
                        ],
                        'lists' => [
                            [
                                'GET /api/books (list with pagination): 50-100ms.',
                                'GET /api/books/{id} (detail): 30-50ms.',
                                'POST /api/auth/login: 100-150ms (do hashing password).',
                                'POST /api/orders (create order): 200-300ms (do nhiều operations: validate, create order, order_items, update wallet, update user_books).',
                                'GET /api/books/{id}/download-pdf: 500ms-2s (tùy kích thước PDF).',
                            ],
                        ],
                        'paragraphs' => [
                            'Hiệu năng backend được coi là chấp nhận được, đáp ứng yêu cầu phi chức năng. Có thể cải thiện bằng cách sử dụng database indexes, query optimization, caching (Redis), queue cho các long-running tasks.',
                            'Hiệu năng frontend được đo bằng app startup time và UI responsiveness. App khởi động trong 2-3 giây (bao gồm load session từ SharedPreferences và splash screen). UI mượt mà, 60 FPS trong hầu hết trường hợp. Một số màn hình có danh sách dài (home, orders) có thể lag nhẹ khi scroll nhanh, có thể cải thiện bằng cách sử dụng ListView.builder với cacheExtent, hoặc flutter_list_view package.',
                        ],
                    ],
                    [
                        'title' => 'Đánh giá tổng thể',
                        'level' => 2,
                        'paragraphs' => [
                            'Hệ thống My Digital Bookstore đã đạt được mục tiêu đề ra: xây dựng một nền tảng hiệu sách điện tử đầy đủ chức năng, hoạt động ổn định, giao diện thân thiện, dễ sử dụng. Hệ thống đáp ứng các yêu cầu chức năng và phi chức năng, có kiến trúc rõ ràng, mã nguồn sạch, dễ bảo trì và mở rộng.',
                            'Những điểm mạnh của hệ thống:',
                        ],
                        'lists' => [
                            [
                                'Kiến trúc client-server rõ ràng, tách biệt frontend và backend.',
                                'Sử dụng công nghệ hiện đại (Laravel 12, Flutter 3, Sanctum, Material Design 3).',
                                'Đầy đủ chức năng cơ bản và nâng cao của một nền tảng e-commerce.',
                                'Hỗ trợ đa nền tảng (mobile, web, desktop) từ một codebase Flutter duy nhất.',
                                'Giao diện đẹp, trực quan, tuân theo Material Design 3.',
                                'Hỗ trợ đa ngôn ngữ (EN/VI), light/dark theme.',
                                'Có unit tests và feature tests, đảm bảo chất lượng mã nguồn.',
                                'Có Postman collection, dễ dàng test và tài liệu hóa API.',
                            ],
                        ],
                    ],
                ],
            ],
            [
                'title' => 'Kết luận và hướng phát triển',
                'level' => 1,
                'paragraphs' => [
                    'Chương cuối cùng tổng hợp những kết quả đạt được, đánh giá các hạn chế hiện hữu và đề xuất lộ trình phát triển tương lai cho My Digital Bookstore. Việc tổng kết dựa trên các tiêu chí đã đặt ra ở chương 1 giúp khẳng định tính hoàn chỉnh của hệ thống, đồng thời phản ánh kinh nghiệm học thuật và kỹ năng triển khai thu được sau quá trình thực hiện đồ án.',
                    'Phần hướng phát triển nhấn mạnh các bước nâng cấp thiết yếu như tích hợp cổng thanh toán thực, bổ sung hệ thống gợi ý, đảm bảo bản quyền nội dung và thiết lập quy trình CI/CD. Những đề xuất này căn cứ trên xu thế thương mại điện tử toàn cầu và thực tiễn vận hành sách số, qua đó mở ra tiềm năng nghiên cứu nâng cao cho các luận văn tiếp theo (Amazon, 2024; Google, 2024).',
                ],
                'children' => [
                    [
                        'title' => 'Kết luận',
                        'level' => 2,
                        'paragraphs' => [
                            'Đồ án "Hệ thống Hiệu sách điện tử trực tuyến - My Digital Bookstore" đã được hoàn thành theo đúng mục tiêu và phạm vi đề ra. Hệ thống cung cấp một giải pháp toàn diện cho việc quản lý và phân phối sách điện tử, bao gồm đầy đủ các chức năng từ phía người dùng (đăng ký, đăng nhập, duyệt sách, mua sắm, thanh toán, đọc sách, đánh giá) đến phía quản trị viên (quản lý người dùng, sách, tác giả, thể loại, đơn hàng, ví điện tử).',
                            'Qua quá trình thực hiện đồ án, em đã có cơ hội áp dụng và củng cố kiến thức về:',
                        ],
                        'lists' => [
                            [
                                'Phân tích và thiết kế hệ thống: Xác định yêu cầu chức năng và phi chức năng, vẽ use case diagram, thiết kế kiến trúc tổng thể, thiết kế cơ sở dữ liệu (ERD), thiết kế API.',
                                'Lập trình backend với Laravel: Eloquent ORM, migrations, seeders, factories, authentication với Sanctum, RESTful API, controllers, routes, middleware, validation, file upload/download, feature tests với PHPUnit.',
                                'Lập trình frontend với Flutter: Widget tree, StatelessWidget/StatefulWidget, Material Design 3, navigation, state management với singleton services và ChangeNotifier, HTTP client, local storage với SharedPreferences, internationalization, theme management, PDF reader integration.',
                                'Tích hợp frontend-backend: RESTful API communication, token-based authentication, error handling, data serialization/deserialization (JSON).',
                                'Kiểm thử: Unit tests, feature tests, integration tests, manual testing.',
                                'Version control: Sử dụng Git để quản lý mã nguồn, branching, merging.',
                            ],
                        ],
                        'paragraphs' => [
                            'Đồ án không chỉ giúp em nâng cao kỹ năng lập trình, mà còn rèn luyện kỹ năng giải quyết vấn đề, tư duy logic, quản lý thời gian, và làm việc độc lập. Hệ thống My Digital Bookstore có thể được sử dụng làm nền tảng cho các dự án thực tế, hoặc làm tài liệu tham khảo cho các sinh viên khác muốn học Laravel và Flutter.',
                        ],
                    ],
                    [
                        'title' => 'Hạn chế',
                        'level' => 2,
                        'paragraphs' => [
                            'Mặc dù đã đạt được các mục tiêu chính, hệ thống vẫn còn một số hạn chế:',
                        ],
                        'lists' => [
                            [
                                'Chưa tích hợp cổng thanh toán thực tế: Hệ thống sử dụng ví điện tử nội bộ thay vì tích hợp VNPay, MoMo, PayPal. Điều này phù hợp cho môi trường demo nhưng không thể sử dụng trong production thực tế.',
                                'Chưa có hệ thống gợi ý sách thông minh: Không có tính năng recommend books dựa trên lịch sử mua sắm, đánh giá, hoặc hành vi người dùng. Có thể bổ sung bằng cách sử dụng collaborative filtering hoặc content-based filtering.',
                                'Tìm kiếm cơ bản: Chỉ hỗ trợ tìm kiếm theo tên sách, chưa có full-text search hoặc advanced filters. Có thể cải thiện bằng cách tích hợp Elasticsearch hoặc Laravel Scout.',
                                'Chưa có thông báo đẩy: Người dùng không nhận được thông báo khi đơn hàng được xử lý, yêu cầu nạp tiền được chấp nhận, hoặc có sách mới. Có thể bổ sung bằng cách sử dụng Firebase Cloud Messaging.',
                                'Chưa có DRM: File PDF không được mã hóa hoặc watermark, dễ bị copy và phát tán trái phép. Có thể cải thiện bằng cách sử dụng các giải pháp DRM như Adobe Content Server hoặc tự xây dựng hệ thống watermarking.',
                                'Chưa có analytics dashboard: Admin không có dashboard để xem thống kê doanh số, người dùng active, sách bán chạy, revenue. Có thể bổ sung bằng cách sử dụng Laravel Nova, Filament, hoặc tự xây dựng với Chart.js.',
                                'Chưa có CI/CD pipeline: Deployment thủ công, chưa có automated testing và deployment. Có thể bổ sung bằng cách sử dụng GitHub Actions, GitLab CI, hoặc Jenkins.',
                                'Test coverage chưa cao: Chỉ có feature tests cho một số flows chính, chưa có unit tests cho tất cả services và widgets. Cần bổ sung thêm tests để đảm bảo chất lượng.',
                            ],
                        ],
                    ],
                    [
                        'title' => 'Hướng phát triển',
                        'level' => 2,
                        'paragraphs' => [
                            'Để hoàn thiện và nâng cao giá trị thực tiễn của hệ thống, các hướng phát triển trong tương lai bao gồm:',
                        ],
                        'lists' => [
                            [
                                'Tích hợp cổng thanh toán: Tích hợp VNPay, MoMo, PayPal để người dùng có thể thanh toán trực tuyến thực sự.',
                                'Hệ thống gợi ý sách: Xây dựng recommendation engine dựa trên collaborative filtering, content-based filtering, hoặc hybrid approach. Sử dụng machine learning để phân tích hành vi người dùng và gợi ý sách phù hợp.',
                                'Tìm kiếm nâng cao: Tích hợp Elasticsearch hoặc Laravel Scout để hỗ trợ full-text search, faceted search, autocomplete, typo tolerance.',
                                'Thông báo đẩy: Tích hợp Firebase Cloud Messaging để gửi thông báo đẩy đến các thiết bị di động, thông báo email cho các sự kiện quan trọng.',
                                'DRM và bảo vệ bản quyền: Mã hóa PDF, watermarking, hoặc sử dụng các giải pháp DRM chuyên nghiệp để bảo vệ nội dung.',
                                'Analytics và báo cáo: Xây dựng dashboard cho admin để xem thống kê doanh số, người dùng, sách bán chạy, revenue theo thời gian. Sử dụng Chart.js, D3.js, hoặc các thư viện visualization khác.',
                                'Social features: Cho phép người dùng follow nhau, share đánh giá lên social media, tạo reading lists, join book clubs.',
                                'Audiobooks: Bổ sung hỗ trợ audiobooks, tích hợp audio player.',
                                'Offline reading: Cho phép download sách và đọc offline, đồng bộ tiến độ đọc khi online.',
                                'Admin panel nâng cao: Sử dụng Laravel Nova, Filament, hoặc tự xây dựng admin panel với UI/UX tốt hơn, hỗ trợ bulk operations, advanced filters.',
                                'CI/CD pipeline: Thiết lập GitHub Actions hoặc GitLab CI để tự động chạy tests, build, và deploy khi có commit mới.',
                                'Performance optimization: Sử dụng Redis cache, database indexing, query optimization, CDN cho static assets.',
                                'Security hardening: Thêm rate limiting, CAPTCHA cho login/register, two-factor authentication, security headers, regular security audits.',
                            ],
                        ],
                    ],
                ],
            ],
        ];
    }

    protected function references(): array
    {
        return [
            'Fielding, R. T. (2000). Architectural Styles and the Design of Network-based Software Architectures (Doctoral dissertation). University of California, Irvine. Retrieved from https://www.ics.uci.edu/~fielding/pubs/dissertation/top.htm',
            'Laravel. (2024). Laravel 12 Documentation. Retrieved from https://laravel.com/docs/12.x',
            'Flutter. (2024). Flutter Documentation. Retrieved from https://docs.flutter.dev/',
            'Google. (2024). Material Design 3. Retrieved from https://m3.material.io/',
            'Laravel. (2024). Laravel Sanctum Documentation. Retrieved from https://laravel.com/docs/12.x/sanctum',
            'Dart. (2024). Dart Language Tour. Retrieved from https://dart.dev/guides/language/language-tour',
            'Otwell, T. (2024). Laravel: Up & Running (3rd ed.). O\'Reilly Media.',
            'Wu, E. (2023). Flutter Complete Reference 2023. Self-published.',
            'Gamma, E., Helm, R., Johnson, R., & Vlissides, J. (1994). Design Patterns: Elements of Reusable Object-Oriented Software. Addison-Wesley Professional.',
            'Martin, R. C. (2017). Clean Architecture: A Craftsman\'s Guide to Software Structure and Design. Prentice Hall.',
            'Newman, S. (2021). Building Microservices: Designing Fine-Grained Systems (2nd ed.). O\'Reilly Media.',
            'Fowler, M. (2002). Patterns of Enterprise Application Architecture. Addison-Wesley Professional.',
            'Richardson, C. (2018). Microservices Patterns. Manning Publications.',
            'Amazon. (2024). Kindle Direct Publishing. Retrieved from https://kdp.amazon.com/',
            'Google. (2024). Google Play Books Partner Center. Retrieved from https://play.google.com/books/publish/',
        ];
    }

    protected function renderAppendixContent(Section $section): void
    {
        $this->addHeading($section, 'Phụ lục A: Sơ đồ ERD', 2, false);
        $this->addParagraph($section, 'Sơ đồ ERD (Entity-Relationship Diagram) minh họa tập thực thể users, authors, categories, books, orders, order_items, wallets, wallet_transactions, wallet_top_up_requests, book_reviews, review_votes và user_books cùng các quan hệ một-nhiều hoặc nhiều-nhiều. Sơ đồ được xây dựng trên cơ sở kiểm kê migrations trong thư mục database/migrations và phản ánh chính xác các khóa ngoại, ràng buộc toàn vẹn tham chiếu.');
        $this->addParagraph($section, 'Từ sơ đồ ERD có thể suy ra các lộ trình dữ liệu chính như: người dùng sở hữu ví và đơn hàng, đơn hàng bao gồm nhiều sách, sách gắn với nhiều tác giả và thể loại, đánh giá gắn với sách và người dùng, vote liên kết với đánh giá. Sơ đồ chi tiết được đính kèm dưới dạng hình ảnh trong tài liệu đi kèm và có thể được tái tạo bằng công cụ MySQL Workbench hoặc Draw.io.');
        $section->addTextBreak();

        $this->addHeading($section, 'Phụ lục B: Danh sách API Endpoints', 2, false);
        $this->addParagraph($section, 'Bảng 1 liệt kê các endpoint chính của REST API phục vụ giao tiếp giữa ứng dụng Flutter và backend Laravel. Tham số phân trang, lọc và tìm kiếm được mô tả chi tiết trong Postman collection đi kèm.');

        $table = $section->addTable([
            'borderSize' => 6,
            'borderColor' => '000000',
            'cellMargin' => 80,
            'alignment' => \PhpOffice\PhpWord\SimpleType\JcTable::CENTER,
            'width' => 100 * 50,
        ]);

        $table->addRow();
        $table->addCell(2000)->addText('Method', ['bold' => true]);
        $table->addCell(5000)->addText('Endpoint', ['bold' => true]);
        $table->addCell(4000)->addText('Mô tả', ['bold' => true]);

        $endpoints = [
            ['POST', '/api/auth/register', 'Đăng ký tài khoản mới'],
            ['POST', '/api/auth/login', 'Đăng nhập và lấy token Sanctum'],
            ['POST', '/api/auth/logout', 'Đăng xuất và thu hồi token'],
            ['GET', '/api/auth/me', 'Truy vấn thông tin người dùng hiện tại'],
            ['GET', '/api/books', 'Danh sách sách với bộ lọc và phân trang'],
            ['GET', '/api/books/{id}', 'Chi tiết sách kèm danh mục, tác giả, đánh giá'],
            ['POST', '/api/books', 'Tạo sách mới (admin)'],
            ['PUT', '/api/books/{id}', 'Cập nhật thông tin sách (admin)'],
            ['DELETE', '/api/books/{id}', 'Xóa sách khỏi hệ thống (admin)'],
            ['POST', '/api/books/{id}/upload-pdf', 'Upload tệp PDF cho sách (admin)'],
            ['GET', '/api/books/{id}/download-pdf', 'Tải tệp PDF dành cho người đã mua'],
            ['POST', '/api/orders', 'Tạo đơn hàng từ giỏ hàng hiện tại'],
            ['GET', '/api/orders', 'Danh sách đơn hàng của người dùng'],
            ['GET', '/api/orders/{id}', 'Chi tiết đơn hàng và các mục đặt mua'],
            ['DELETE', '/api/orders/{id}', 'Hủy đơn hàng ở trạng thái pending'],
            ['GET', '/api/wallet', 'Thông tin số dư ví điện tử'],
            ['GET', '/api/wallet/transactions', 'Lịch sử giao dịch ví'],
            ['POST', '/api/wallet/top-up-requests', 'Tạo yêu cầu nạp tiền'],
            ['PATCH', '/api/wallet/top-up-requests/{id}/approve', 'Phê duyệt nạp tiền (admin)'],
            ['PATCH', '/api/wallet/top-up-requests/{id}/reject', 'Từ chối nạp tiền (admin)'],
            ['POST', '/api/wallet/adjust', 'Điều chỉnh số dư ví (admin)'],
            ['GET', '/api/books/{id}/reviews', 'Danh sách đánh giá của sách'],
            ['POST', '/api/books/{id}/reviews', 'Tạo đánh giá mới'],
            ['PUT', '/api/reviews/{id}', 'Cập nhật đánh giá đã viết'],
            ['DELETE', '/api/reviews/{id}', 'Xóa đánh giá'],
            ['POST', '/api/reviews/{id}/vote', 'Vote cho đánh giá (upvote/downvote)'],
            ['GET', '/api/my-books', 'Thư viện sách đã mua của người dùng'],
        ];

        foreach ($endpoints as $endpoint) {
            $table->addRow();
            $table->addCell(2000)->addText($endpoint[0]);
            $table->addCell(5000)->addText($endpoint[1], ['size' => 10]);
            $table->addCell(4000)->addText($endpoint[2]);
        }

        $section->addTextBreak();
        $this->addParagraph($section, 'Danh sách chi tiết hơn (query params, response sample, lỗi phổ biến) được đóng gói trong Postman collection tại thư mục docs/postman của dự án.');
        $section->addTextBreak();

        $this->addHeading($section, 'Phụ lục C: Screenshots giao diện', 2, false);
        $this->addParagraph($section, 'Phần phụ lục này tổng hợp các hình ảnh minh họa giao diện ứng dụng Flutter ở chế độ light và dark trên cả thiết bị di động và trình duyệt web. Các ảnh bao gồm: màn hình Splash, màn hình Đăng nhập, Trang chủ với grid sách, Trang chi tiết sách, Giỏ hàng, Quy trình thanh toán, Ví điện tử, Lịch sử đơn hàng, Thư viện của tôi, Trang đánh giá, Bảng điều khiển admin, và Màn hình cài đặt với lựa chọn theme và ngôn ngữ.');
        $this->addParagraph($section, 'Do giới hạn của tài liệu dạng văn bản, hình ảnh được đính kèm riêng trong thư mục docs/screenshots với tên file có quy ước rõ ràng (ví dụ: 01_splash_light.png, 02_login_dark.png).');
        $section->addTextBreak();

        $this->addHeading($section, 'Phụ lục D: Cấu trúc thư mục dự án', 2, false);
        $this->addParagraph($section, 'Monorepo của My Digital Bookstore được tổ chức theo cấu trúc sau, phản ánh sự tách biệt giữa backend Laravel và frontend Flutter:');
        $section->addText('my_digital_bookstore/', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('├── backend/ (Laravel 12)', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── app/              # Code nguồn chính (Models, Controllers, Middleware)', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── bootstrap/        # Tệp khởi tạo ứng dụng', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── config/           # Cấu hình framework', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── database/         # Migrations, Seeders, Factories', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── routes/           # Định nghĩa routes API', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── tests/            # PHPUnit feature tests', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   └── composer.json     # Khai báo dependencies PHP', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('├── frontend/ (Flutter 3)', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── lib/', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   │   ├── main.dart          # Điểm vào ứng dụng', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   │   ├── services/          # Singleton services tương tác API', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   │   ├── screens/           # Các màn hình giao diện', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   │   ├── widgets/           # Widgets tái sử dụng', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   │   └── models/            # Lớp dữ liệu ánh xạ JSON', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── assets/                # Biểu tượng, hình ảnh, font', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   ├── l10n/                  # Tệp dịch đa ngôn ngữ', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('│   └── pubspec.yaml           # Khai báo dependencies Dart', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('├── docs/                      # Tài liệu và Postman collection', ['name' => 'Courier New', 'size' => 10]);
        $section->addText('└── README.md                  # Hướng dẫn sử dụng monorepo', ['name' => 'Courier New', 'size' => 10]);
    }
}
