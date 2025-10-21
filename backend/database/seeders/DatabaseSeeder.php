<?php

namespace Database\Seeders;

use App\Models\Author;
use App\Models\Book;
use App\Models\BookReview;
use App\Models\Category;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ReviewVote;
use App\Models\User;
use App\Models\UserBook;
use App\Models\Wallet;
use App\Models\WalletTopUpRequest;
use App\Models\WalletTransaction;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // ==================== USERS ====================
        $admin = User::factory()->create([
            'name' => 'Admin User',
            'email' => 'admin@example.com',
            'password' => 'Password123!',
            'role' => 'admin',
            'phone' => '0900000001',
            'dob' => '1990-01-01',
            'gender' => 'male',
            'terms_accepted_at' => now(),
        ]);

        $users = collect([
            [
                'name' => 'Nguyễn Văn A',
                'email' => 'nguyenvana@example.com',
                'phone' => '0912345678',
                'dob' => '1995-05-15',
                'gender' => 'male',
            ],
            [
                'name' => 'Trần Thị B',
                'email' => 'tranthib@example.com',
                'phone' => '0923456789',
                'dob' => '1998-08-20',
                'gender' => 'female',
            ],
            [
                'name' => 'Lê Hoàng C',
                'email' => 'lehoangc@example.com',
                'phone' => '0934567890',
                'dob' => '1992-03-10',
                'gender' => 'male',
            ],
            [
                'name' => 'Phạm Mai D',
                'email' => 'phammaid@example.com',
                'phone' => '0945678901',
                'dob' => '2000-12-25',
                'gender' => 'female',
            ],
            [
                'name' => 'Hoàng Minh E',
                'email' => 'hoangminhe@example.com',
                'phone' => '0956789012',
                'dob' => '1997-07-07',
                'gender' => 'male',
            ],
        ])->map(function ($data) {
            return User::factory()->create([
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => 'Password123!',
                'phone' => $data['phone'],
                'dob' => $data['dob'],
                'gender' => $data['gender'],
                'terms_accepted_at' => now(),
            ]);
        });

        $allUsers = $users->prepend($admin);

        // ==================== CATEGORIES ====================
        $categoryData = [
            ['name' => 'Văn học Việt Nam', 'description' => 'Tác phẩm văn học từ các tác giả Việt Nam'],
            ['name' => 'Tiểu thuyết', 'description' => 'Truyện dài, kể chuyện về cuộc sống và con người'],
            ['name' => 'Khoa học viễn tưởng', 'description' => 'Câu chuyện về tương lai, công nghệ và khoa học'],
            ['name' => 'Kinh doanh & Tài chính', 'description' => 'Sách về kinh doanh, đầu tư và quản lý tài chính'],
            ['name' => 'Phát triển bản thân', 'description' => 'Sách giúp cải thiện kỹ năng và phát triển cá nhân'],
            ['name' => 'Lịch sử', 'description' => 'Sách về lịch sử thế giới và Việt Nam'],
            ['name' => 'Tâm lý học', 'description' => 'Sách về tâm lý con người và hành vi'],
            ['name' => 'Triết học', 'description' => 'Sách về triết lý sống và tư tưởng'],
            ['name' => 'Công nghệ', 'description' => 'Sách về công nghệ thông tin và lập trình'],
            ['name' => 'Thiếu nhi', 'description' => 'Sách dành cho trẻ em và thanh thiếu niên'],
            ['name' => 'Ngoại ngữ', 'description' => 'Sách học tiếng Anh và các ngoại ngữ khác'],
            ['name' => 'Kỹ năng sống', 'description' => 'Sách hướng dẫn các kỹ năng cần thiết trong cuộc sống'],
        ];

        $categories = collect($categoryData)->map(function ($data) {
            return Category::create([
                'name' => $data['name'],
                'slug' => Str::slug($data['name']),
                'description' => $data['description'],
            ]);
        });

        // ==================== AUTHORS ====================
        $authorData = [
            ['name' => 'Nguyễn Nhật Ánh', 'bio' => 'Nhà văn Việt Nam nổi tiếng với các tác phẩm văn học thiếu nhi'],
            ['name' => 'Tô Hoài', 'bio' => 'Nhà văn, nhà thơ Việt Nam, tác giả của Dế Mèn phiêu lưu ký'],
            ['name' => 'Nam Cao', 'bio' => 'Nhà văn hiện thực Việt Nam thế kỷ 20'],
            ['name' => 'Ngô Tất Tố', 'bio' => 'Nhà văn Việt Nam, tác giả Tắt đèn'],
            ['name' => 'Vũ Trọng Phụng', 'bio' => 'Nhà văn, nhà báo Việt Nam, nổi tiếng với phong cách viết châm biếm'],
            ['name' => 'Haruki Murakami', 'bio' => 'Tiểu thuyết gia và nhà văn ngắn người Nhật Bản'],
            ['name' => 'Paulo Coelho', 'bio' => 'Nhà văn Brazil, tác giả của Nhà giả kim'],
            ['name' => 'Dale Carnegie', 'bio' => 'Tác giả người Mỹ, nổi tiếng với sách Đắc nhân tâm'],
            ['name' => 'Napoleon Hill', 'bio' => 'Tác giả sách tự giúp người Mỹ'],
            ['name' => 'Robert Kiyosaki', 'bio' => 'Doanh nhân và tác giả sách về tài chính'],
            ['name' => 'Stephen Covey', 'bio' => 'Tác giả sách 7 thói quen của người thành đạt'],
            ['name' => 'Yuval Noah Harari', 'bio' => 'Sử gia người Israel, tác giả Sapiens'],
            ['name' => 'Malcolm Gladwell', 'bio' => 'Nhà báo và tác giả người Canada'],
            ['name' => 'Mark Manson', 'bio' => 'Blogger và tác giả người Mỹ'],
            ['name' => 'James Clear', 'bio' => 'Tác giả sách Atomic Habits'],
            ['name' => 'Tony Robbins', 'bio' => 'Diễn giả động lực và tác giả người Mỹ'],
            ['name' => 'Simon Sinek', 'bio' => 'Tác giả và diễn giả người Anh-Mỹ'],
            ['name' => 'Cal Newport', 'bio' => 'Giáo sư khoa học máy tính và tác giả'],
            ['name' => 'Daniel Kahneman', 'bio' => 'Nhà tâm lý học đoạt giải Nobel'],
            ['name' => 'Ray Dalio', 'bio' => 'Nhà đầu tư và tác giả người Mỹ'],
        ];

        $authors = collect($authorData)->map(function ($data) {
            return Author::create([
                'name' => $data['name'],
                'slug' => Str::slug($data['name']),
                'bio' => $data['bio'],
            ]);
        });

        // ==================== BOOKS ====================
        $bookData = [
            // Văn học Việt Nam
            [
                'title' => 'Tôi Thấy Hoa Vàng Trên Cỏ Xanh',
                'subtitle' => 'Ký ức tuổi thơ',
                'description' => 'Câu chuyện về tuổi thơ dữ dội và những kỷ niệm không thể nào quên của hai anh em Thiều và Tường ở một vùng quê Việt Nam.',
                'credit_price' => 150,
                'available_copies' => 100,
                'isbn' => '9786041008809',
                'language' => 'vi',
                'published_at' => now()->subYears(10),
                'status' => 'published',
                'category' => 'Văn học Việt Nam',
                'authors' => ['Nguyễn Nhật Ánh'],
                'tags' => ['tuổi thơ', 'gia đình', 'tình cảm'],
            ],
            [
                'title' => 'Mắt Biếc',
                'subtitle' => 'Chuyện tình đầu dời dang',
                'description' => 'Một câu chuyện tình đầu đẹp đẽ, trong sáng nhưng cũng đầy day dứt và nuối tiếc.',
                'credit_price' => 120,
                'available_copies' => 150,
                'isbn' => '9786041001763',
                'language' => 'vi',
                'published_at' => now()->subYears(8),
                'status' => 'published',
                'category' => 'Văn học Việt Nam',
                'authors' => ['Nguyễn Nhật Ánh'],
                'tags' => ['tình yêu', 'thanh xuân'],
            ],
            [
                'title' => 'Dế Mèn Phiêu Lưu Ký',
                'subtitle' => 'Cuộc phiêu lưu của chú dế mèn',
                'description' => 'Tác phẩm văn học thiếu nhi kinh điển về cuộc phiêu lưu của chú Dế Mèn.',
                'credit_price' => 100,
                'available_copies' => 200,
                'isbn' => '9786041012509',
                'language' => 'vi',
                'published_at' => now()->subYears(70),
                'status' => 'published',
                'category' => 'Thiếu nhi',
                'authors' => ['Tô Hoài'],
                'tags' => ['thiếu nhi', 'phiêu lưu'],
            ],

            // Tiểu thuyết
            [
                'title' => 'Kafka Bên Bờ Biển',
                'subtitle' => 'Hành trình tìm kiếm bản thân',
                'description' => 'Một tiểu thuyết siêu thực về hành trình tìm kiếm bản thân của cậu bé 15 tuổi Kafka Tamura.',
                'credit_price' => 200,
                'available_copies' => 80,
                'isbn' => '9786041055506',
                'language' => 'vi',
                'published_at' => now()->subYears(5),
                'status' => 'published',
                'category' => 'Tiểu thuyết',
                'authors' => ['Haruki Murakami'],
                'tags' => ['siêu thực', 'tâm lý'],
            ],
            [
                'title' => 'Nhà Giả Kim',
                'subtitle' => 'Hành trình theo đuổi ước mơ',
                'description' => 'Câu chuyện về chàng chăn cừu Santiago trên hành trình tìm kiếm kho báu và ý nghĩa cuộc sống.',
                'credit_price' => 180,
                'available_copies' => 120,
                'isbn' => '9786041046689',
                'language' => 'vi',
                'published_at' => now()->subYears(15),
                'status' => 'published',
                'category' => 'Tiểu thuyết',
                'authors' => ['Paulo Coelho'],
                'tags' => ['triết lý', 'ước mơ', 'phiêu lưu'],
            ],

            // Phát triển bản thân
            [
                'title' => 'Đắc Nhân Tâm',
                'subtitle' => 'Nghệ thuật giao tiếp và thu phục lòng người',
                'description' => 'Cuốn sách kinh điển về kỹ năng giao tiếp và xây dựng mối quan hệ.',
                'credit_price' => 160,
                'available_copies' => 250,
                'isbn' => '9786041046696',
                'language' => 'vi',
                'published_at' => now()->subYears(20),
                'status' => 'published',
                'category' => 'Phát triển bản thân',
                'authors' => ['Dale Carnegie'],
                'tags' => ['kỹ năng mềm', 'giao tiếp'],
            ],
            [
                'title' => 'Atomic Habits',
                'subtitle' => 'Thay đổi tí hon - Hiệu quả bất ngờ',
                'description' => 'Hướng dẫn cách xây dựng thói quen tốt và loại bỏ thói quen xấu một cách khoa học.',
                'credit_price' => 220,
                'available_copies' => 100,
                'isbn' => '9786041133587',
                'language' => 'vi',
                'published_at' => now()->subYears(2),
                'status' => 'published',
                'category' => 'Phát triển bản thân',
                'authors' => ['James Clear'],
                'tags' => ['thói quen', 'năng suất'],
            ],
            [
                'title' => '7 Thói Quen Của Người Thành Đạt',
                'subtitle' => 'Bí quyết hiệu quả cá nhân',
                'description' => 'Những nguyên tắc cơ bản để đạt được thành công trong cuộc sống và công việc.',
                'credit_price' => 190,
                'available_copies' => 150,
                'isbn' => '9786041046702',
                'language' => 'vi',
                'published_at' => now()->subYears(12),
                'status' => 'published',
                'category' => 'Phát triển bản thân',
                'authors' => ['Stephen Covey'],
                'tags' => ['thành công', 'hiệu quả'],
            ],

            // Kinh doanh & Tài chính
            [
                'title' => 'Dạy Con Làm Giàu',
                'subtitle' => 'Tập 1 - Tài chính cá nhân',
                'description' => 'Những bài học về tài chính và đầu tư từ người cha giàu có.',
                'credit_price' => 210,
                'available_copies' => 90,
                'isbn' => '9786041133600',
                'language' => 'vi',
                'published_at' => now()->subYears(8),
                'status' => 'published',
                'category' => 'Kinh doanh & Tài chính',
                'authors' => ['Robert Kiyosaki'],
                'tags' => ['tài chính', 'đầu tư'],
            ],
            [
                'title' => 'Nguyên Lý',
                'subtitle' => 'Principles - Life and Work',
                'description' => 'Những nguyên tắc sống và làm việc từ một trong những nhà đầu tư thành công nhất.',
                'credit_price' => 280,
                'available_copies' => 60,
                'isbn' => '9786041133617',
                'language' => 'vi',
                'published_at' => now()->subYears(3),
                'status' => 'published',
                'category' => 'Kinh doanh & Tài chính',
                'authors' => ['Ray Dalio'],
                'tags' => ['nguyên tắc', 'quản lý'],
            ],

            // Lịch sử
            [
                'title' => 'Sapiens: Lược Sử Loài Người',
                'subtitle' => 'Từ động vật đến thượng đế',
                'description' => 'Câu chuyện về sự tiến hóa của loài người từ săn bắt hái lượm đến thời đại hiện đại.',
                'credit_price' => 250,
                'available_copies' => 70,
                'isbn' => '9786041087507',
                'language' => 'vi',
                'published_at' => now()->subYears(6),
                'status' => 'published',
                'category' => 'Lịch sử',
                'authors' => ['Yuval Noah Harari'],
                'tags' => ['lịch sử', 'nhân loại'],
            ],

            // Tâm lý học
            [
                'title' => 'Thinking, Fast and Slow',
                'subtitle' => 'Tư duy nhanh và chậm',
                'description' => 'Khám phá hai hệ thống tư duy của con người và cách chúng ảnh hưởng đến quyết định.',
                'credit_price' => 240,
                'available_copies' => 50,
                'isbn' => '9786041133624',
                'language' => 'vi',
                'published_at' => now()->subYears(4),
                'status' => 'published',
                'category' => 'Tâm lý học',
                'authors' => ['Daniel Kahneman'],
                'tags' => ['tâm lý', 'quyết định'],
            ],
            [
                'title' => 'The Subtle Art of Not Giving a F*ck',
                'subtitle' => 'Nghệ thuật tinh tế của việc đếch quan tâm',
                'description' => 'Một cách tiếp cận mới về việc sống một cuộc đời tốt đẹp.',
                'credit_price' => 170,
                'available_copies' => 110,
                'isbn' => '9786041133631',
                'language' => 'vi',
                'published_at' => now()->subYears(5),
                'status' => 'published',
                'category' => 'Phát triển bản thân',
                'authors' => ['Mark Manson'],
                'tags' => ['tâm lý', 'sống tích cực'],
            ],

            // Công nghệ
            [
                'title' => 'Deep Work',
                'subtitle' => 'Làm việc chuyên sâu',
                'description' => 'Hướng dẫn cách tập trung cao độ trong thời đại nhiễu loạn.',
                'credit_price' => 200,
                'available_copies' => 80,
                'isbn' => '9786041133648',
                'language' => 'vi',
                'published_at' => now()->subYears(3),
                'status' => 'published',
                'category' => 'Công nghệ',
                'authors' => ['Cal Newport'],
                'tags' => ['năng suất', 'tập trung'],
            ],

            // Kỹ năng sống
            [
                'title' => 'Start With Why',
                'subtitle' => 'Tại sao lại bắt đầu với TẠI SAO',
                'description' => 'Khám phá sức mạnh của việc hiểu rõ mục đích và động lực cốt lõi.',
                'credit_price' => 190,
                'available_copies' => 100,
                'isbn' => '9786041133655',
                'language' => 'vi',
                'published_at' => now()->subYears(7),
                'status' => 'published',
                'category' => 'Kỹ năng sống',
                'authors' => ['Simon Sinek'],
                'tags' => ['lãnh đạo', 'mục đích'],
            ],

            // Thêm sách để đủ dữ liệu test
            [
                'title' => 'Outliers',
                'subtitle' => 'Câu chuyện về thành công',
                'description' => 'Phân tích những yếu tố ẩn sau thành công của những người xuất chúng.',
                'credit_price' => 180,
                'available_copies' => 90,
                'isbn' => '9786041133662',
                'language' => 'vi',
                'published_at' => now()->subYears(9),
                'status' => 'published',
                'category' => 'Phát triển bản thân',
                'authors' => ['Malcolm Gladwell'],
                'tags' => ['thành công', 'nghiên cứu'],
            ],
            [
                'title' => 'Awaken the Giant Within',
                'subtitle' => 'Đánh thức người khổng lồ trong bạn',
                'description' => 'Hướng dẫn nắm quyền kiểm soát số phận và tạo ra cuộc sống bạn mong muốn.',
                'credit_price' => 230,
                'available_copies' => 70,
                'isbn' => '9786041133679',
                'language' => 'vi',
                'published_at' => now()->subYears(11),
                'status' => 'published',
                'category' => 'Phát triển bản thân',
                'authors' => ['Tony Robbins'],
                'tags' => ['động lực', 'thay đổi'],
            ],
            [
                'title' => 'Tư Duy Ngược',
                'subtitle' => 'The Art of Thinking Clearly',
                'description' => '99 sai lầm tư duy phổ biến và cách khắc phục.',
                'credit_price' => 160,
                'available_copies' => 120,
                'isbn' => '9786041133686',
                'language' => 'vi',
                'published_at' => now()->subYears(4),
                'status' => 'published',
                'category' => 'Tâm lý học',
                'authors' => ['Daniel Kahneman'],
                'tags' => ['tư duy', 'logic'],
            ],
            [
                'title' => 'Bí Mật Tư Duy Triệu Phú',
                'subtitle' => 'Think and Grow Rich',
                'description' => 'Triết lý thành công từ những người giàu có nhất thế giới.',
                'credit_price' => 170,
                'available_copies' => 140,
                'isbn' => '9786041133693',
                'language' => 'vi',
                'published_at' => now()->subYears(25),
                'status' => 'published',
                'category' => 'Kinh doanh & Tài chính',
                'authors' => ['Napoleon Hill'],
                'tags' => ['thành công', 'giàu có'],
            ],
            [
                'title' => 'Nghệ Thuật Bán Hàng',
                'subtitle' => 'The Art of Selling',
                'description' => 'Những kỹ năng cần thiết để trở thành người bán hàng xuất sắc.',
                'credit_price' => 150,
                'available_copies' => 100,
                'isbn' => '9786041133709',
                'language' => 'vi',
                'published_at' => now()->subYears(6),
                'status' => 'published',
                'category' => 'Kinh doanh & Tài chính',
                'authors' => ['Dale Carnegie'],
                'tags' => ['bán hàng', 'kỹ năng'],
            ],
        ];

        $books = collect($bookData)->map(function ($data) use ($categories, $authors) {
            $category = $categories->firstWhere('name', $data['category']);

            $book = Book::create([
                'category_id' => $category?->id,
                'title' => $data['title'],
                'subtitle' => $data['subtitle'],
                'description' => $data['description'],
                'credit_price' => $data['credit_price'],
                'available_copies' => $data['available_copies'],
                'isbn' => $data['isbn'],
                'language' => $data['language'],
                'published_at' => $data['published_at'],
                'status' => $data['status'],
                'tags' => $data['tags'],
            ]);

            $authorIds = collect($data['authors'])
                ->map(fn ($name) => $authors->firstWhere('name', $name)?->id)
                ->filter()
                ->all();

            if (! empty($authorIds)) {
                $book->authors()->sync($authorIds);
            }

            return $book;
        });

        // ==================== WALLETS ====================
        $allUsers->each(function ($user) use ($admin) {
            $wallet = Wallet::create([
                'user_id' => $user->id,
                'balance' => 0,
            ]);

            // Give users some initial balance
            $initialBalance = $user->role === 'admin' ? 10000 : rand(500, 2000);

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'credit',
                'amount' => $initialBalance,
                'balance_before' => 0,
                'balance_after' => $initialBalance,
                'performed_by' => $admin->id,
                'description' => 'Initial balance from seeder',
                'meta' => ['source' => 'seed'],
            ]);

            $wallet->update(['balance' => $initialBalance]);
        });

        // ==================== ORDERS & USER BOOKS ====================
        $users->each(function ($user) use ($books) {
            // Each user purchases 2-5 random books
            $purchasedBooks = $books->random(rand(2, 5));
            $totalCost = $purchasedBooks->sum('credit_price');

            $order = Order::create([
                'user_id' => $user->id,
                'total_credit' => $totalCost,
                'status' => 'completed',
                'placed_at' => now()->subDays(rand(1, 30)),
                'completed_at' => now()->subDays(rand(1, 29)),
            ]);

            foreach ($purchasedBooks as $book) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'book_id' => $book->id,
                    'quantity' => 1,
                    'unit_credit' => $book->credit_price,
                    'total_credit' => $book->credit_price,
                ]);

                UserBook::create([
                    'user_id' => $user->id,
                    'book_id' => $book->id,
                    'order_id' => $order->id,
                    'first_purchased_at' => $order->completed_at,
                    'last_purchased_at' => $order->completed_at,
                    'last_opened_at' => rand(0, 1) ? now()->subDays(rand(0, 7)) : null,
                ]);
            }

            // Deduct from wallet
            $wallet = Wallet::where('user_id', $user->id)->first();
            $balanceBefore = $wallet->balance;
            $balanceAfter = $balanceBefore - $totalCost;

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'debit',
                'amount' => $totalCost,
                'balance_before' => $balanceBefore,
                'balance_after' => $balanceAfter,
                'order_id' => $order->id,
                'performed_by' => $user->id,
                'description' => 'Book purchase',
                'meta' => ['order_id' => $order->id],
            ]);

            $wallet->update(['balance' => $balanceAfter]);
        });

        // ==================== REVIEWS ====================
        $books->each(function ($book) use ($allUsers) {
            // Random 2-6 users review each book
            $reviewers = $allUsers->random(rand(2, min(6, $allUsers->count())));

            foreach ($reviewers as $reviewer) {
                $review = BookReview::create([
                    'book_id' => $book->id,
                    'user_id' => $reviewer->id,
                    'rating' => rand(3, 5),
                    'title' => fake()->sentence(rand(3, 8)),
                    'comment' => fake()->paragraph(rand(2, 4)),
                    'helpful_count' => 0,
                    'not_helpful_count' => 0,
                ]);

                // Random users vote on this review
                $voters = $allUsers->except($reviewer->id)->random(rand(0, 4));
                foreach ($voters as $voter) {
                    $voteType = rand(0, 1) ? 'like' : 'dislike';

                    ReviewVote::create([
                        'review_id' => $review->id,
                        'user_id' => $voter->id,
                        'vote_type' => $voteType,
                    ]);

                    // Update counts
                    if ($voteType === 'like') {
                        $review->increment('helpful_count');
                    } else {
                        $review->increment('not_helpful_count');
                    }
                }
            }
        });

        // ==================== TOP-UP REQUESTS ====================
        $users->random(2)->each(function ($user) use ($admin) {
            // Pending request
            WalletTopUpRequest::create([
                'user_id' => $user->id,
                'amount' => rand(500, 2000),
                'status' => 'pending',
                'note' => 'Cần nạp thêm tiền để mua sách',
            ]);

            // Approved request
            $approvedAmount = rand(1000, 3000);
            WalletTopUpRequest::create([
                'user_id' => $user->id,
                'amount' => $approvedAmount,
                'status' => 'approved',
                'note' => 'Đã chuyển khoản',
                'response_note' => 'Đã xác nhận thanh toán',
                'responded_by' => $admin->id,
                'responded_at' => now()->subDays(rand(1, 5)),
            ]);

            // Rejected request
            WalletTopUpRequest::create([
                'user_id' => $user->id,
                'amount' => rand(500, 1500),
                'status' => 'rejected',
                'note' => 'Yêu cầu nạp tiền',
                'response_note' => 'Chưa nhận được thanh toán',
                'responded_by' => $admin->id,
                'responded_at' => now()->subDays(rand(1, 3)),
            ]);
        });

        $this->command->info('✅ Database seeded successfully!');
        $this->command->info("📊 Summary:");
        $this->command->info("   - Users: {$allUsers->count()} (1 admin, {$users->count()} regular)");
        $this->command->info("   - Categories: {$categories->count()}");
        $this->command->info("   - Authors: {$authors->count()}");
        $this->command->info("   - Books: {$books->count()}");
        $this->command->info("   - Reviews: ".BookReview::count());
        $this->command->info("   - Review Votes: ".ReviewVote::count());
        $this->command->info("   - Orders: ".Order::count());
        $this->command->info("   - Wallets: ".Wallet::count());
        $this->command->info("   - Top-up Requests: ".WalletTopUpRequest::count());
    }
}
