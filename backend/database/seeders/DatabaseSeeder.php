<?php

namespace Database\Seeders;

use App\Models\Author;
use App\Models\Book;
use App\Models\BookReview;
use App\Models\Category;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Database\Seeder;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::factory()->create([
            'name' => 'Admin User',
            'email' => 'admin@example.com',
            'password' => 'Password123!',
            'role' => 'admin',
            'phone' => '0900000001',
            'terms_accepted_at' => now(),
        ]);

        $reader = User::factory()->create([
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'Password123!',
            'role' => 'user',
            'phone' => '0900000002',
            'terms_accepted_at' => now(),
        ]);

        $categories = collect([
            ['name' => 'Science Fiction', 'description' => 'Stories that explore futuristic science and technology.'],
            ['name' => 'Business & Finance', 'description' => 'Books about entrepreneurship, investing, and business strategy.'],
            ['name' => 'Self-Help', 'description' => 'Guides to improve personal skills and wellbeing.'],
        ])->map(function (array $data) {
            $data['slug'] = Str::slug($data['name']);

            return Category::create($data);
        });

        $authors = collect([
            ['name' => 'Nguyen Nhat Anh'],
            ['name' => 'Harper Lin'],
            ['name' => 'Tony Robbins'],
        ])->map(fn (array $data) => Author::create([
            'name' => $data['name'],
            'slug' => Str::slug($data['name']),
            'bio' => $data['name'].' biography.',
        ]));

        $books = collect([
            [
                'title' => 'Stars Beyond The Horizon',
                'subtitle' => 'A Journey Through Space',
                'description' => 'An epic exploration across galaxies with a crew of explorers.',
                'credit_price' => 250,
                'isbn' => '9780000000011',
                'language' => 'en',
                'cover_image_url' => null,
                'file_url' => null,
                'published_at' => now()->subMonths(6),
                'status' => 'published',
                'category' => 'Science Fiction',
                'authors' => ['Harper Lin'],
                'tags' => ['space', 'exploration'],
            ],
            [
                'title' => 'Mastering Your Inner Power',
                'subtitle' => 'Unlock the best version of yourself',
                'description' => 'Practical exercises to build lasting habits and resilience.',
                'credit_price' => 200,
                'isbn' => '9780000000028',
                'language' => 'en',
                'cover_image_url' => null,
                'file_url' => null,
                'published_at' => now()->subMonths(2),
                'status' => 'published',
                'category' => 'Self-Help',
                'authors' => ['Tony Robbins'],
                'tags' => ['self-improvement', 'habits'],
            ],
            [
                'title' => 'Starting Smart Investments',
                'subtitle' => 'Beginner-friendly strategies',
                'description' => 'Fundamentals of investing wisely with small budgets.',
                'credit_price' => 180,
                'isbn' => '9780000000035',
                'language' => 'en',
                'cover_image_url' => null,
                'file_url' => null,
                'published_at' => now()->subMonths(1),
                'status' => 'published',
                'category' => 'Business & Finance',
                'authors' => ['Nguyen Nhat Anh'],
                'tags' => ['investing', 'beginner'],
            ],
        ])->map(function (array $data) use ($categories, $authors) {
            /** @var \App\Models\Category|null $category */
            $category = $categories->firstWhere('name', $data['category']);

            $book = Book::create([
                'category_id' => $category?->id,
                'title' => $data['title'],
                'subtitle' => $data['subtitle'],
                'description' => $data['description'],
                'credit_price' => $data['credit_price'],
                'isbn' => $data['isbn'],
                'language' => $data['language'],
                'cover_image_url' => $data['cover_image_url'],
                'file_url' => $data['file_url'],
                'published_at' => $data['published_at'],
                'status' => $data['status'],
            ]);

            $authorIds = collect($data['authors'])
                ->map(fn (string $name) => optional($authors->firstWhere('name', $name))->id)
                ->filter()
                ->all();

            if (! empty($authorIds)) {
                $book->authors()->sync($authorIds);
            }

            return $book;
        });

        $adminWallet = Wallet::create([
            'user_id' => $admin->id,
            'balance' => 0,
        ]);

        $readerWallet = Wallet::create([
            'user_id' => $reader->id,
            'balance' => 0,
        ]);

        $initialTopUp = 1000;
        $readerWallet->update(['balance' => $initialTopUp]);

        WalletTransaction::create([
            'wallet_id' => $readerWallet->id,
            'type' => 'credit',
            'amount' => $initialTopUp,
            'balance_before' => 0,
            'balance_after' => $initialTopUp,
            'performed_by' => $admin->id,
            'description' => 'Initial credit top-up by admin',
            'meta' => ['source' => 'seed'],
        ]);

        $order = Order::create([
            'user_id' => $reader->id,
            'total_credit' => 450,
            'status' => 'completed',
            'note' => 'Sample completed order from seeder',
            'placed_at' => now()->subDays(2),
            'completed_at' => now()->subDays(1),
        ]);

        // Seed book reviews
        $users = collect([$admin, $reader]);

        foreach ($books as $book) {
            foreach ($users as $user) {
                BookReview::updateOrCreate([
                    'book_id' => $book->id,
                    'user_id' => $user->id,
                ], [
                    'rating' => fake()->numberBetween(3, 5),
                    'comment' => fake()->sentence(12),
                ]);
            }
        }

        $orderedBooks = $books->take(2);
        $itemTotal = 0;

        foreach ($orderedBooks as $book) {
            $quantity = 1;
            $total = $book->credit_price * $quantity;
            $itemTotal += $total;

            OrderItem::create([
                'order_id' => $order->id,
                'book_id' => $book->id,
                'quantity' => $quantity,
                'unit_credit' => $book->credit_price,
                'total_credit' => $total,
            ]);
        }

        $order->update(['total_credit' => $itemTotal]);

        $balanceAfterPurchase = max(0, $initialTopUp - $itemTotal);
        WalletTransaction::create([
            'wallet_id' => $readerWallet->id,
            'type' => 'debit',
            'amount' => $itemTotal,
            'balance_before' => $initialTopUp,
            'balance_after' => $balanceAfterPurchase,
            'order_id' => $order->id,
            'performed_by' => $reader->id,
            'description' => 'Purchase of digital books',
            'meta' => ['items' => $orderedBooks->pluck('title')],
        ]);

        $readerWallet->update(['balance' => $balanceAfterPurchase]);

        WalletTransaction::create([
            'wallet_id' => $adminWallet->id,
            'type' => 'credit',
            'amount' => 2000,
            'balance_before' => 0,
            'balance_after' => 2000,
            'performed_by' => $admin->id,
            'description' => 'Admin wallet seed balance',
            'meta' => ['source' => 'seed'],
        ]);

        $adminWallet->update(['balance' => 2000]);
    }
}
