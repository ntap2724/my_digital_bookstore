<?php

namespace Tests\Feature;

use App\Models\Book;
use App\Models\Category;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PdfTextExtractionTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @var list<string>
     */
    private array $pageTexts = [];

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();

        $this->pageTexts = [
            'Page 1 content for testing.',
            'Page 2 content for testing.',
            'Page 3 content for testing.',
            'Page 4 content for testing.',
            'Page 5 content for testing.',
        ];

        $this->createTestPdf($this->pageTexts);
    }

    protected function tearDown(): void
    {
        $pdfPath = storage_path('app/books/test-book.pdf');

        if (file_exists($pdfPath)) {
            unlink($pdfPath);
        }

        parent::tearDown();
    }

    private function createTestPdf(array $pageTexts): void
    {
        $booksDir = storage_path('app/books');

        if (! is_dir($booksDir)) {
            mkdir($booksDir, 0755, true);
        }

        $pdf = new \TCPDF();
        $pdf->setPrintHeader(false);
        $pdf->setPrintFooter(false);

        foreach ($pageTexts as $text) {
            $pdf->AddPage();
            $pdf->SetFont('helvetica', '', 12);
            $pdf->MultiCell(0, 0, $text);
        }

        $pdf->Output($booksDir.'/test-book.pdf', 'F');
    }

    private function createBookWithPdf(): Book
    {
        $category = Category::create([
            'name' => 'Test Category',
            'slug' => 'test-category',
        ]);

        return Book::create([
            'category_id' => $category->id,
            'title' => 'Test Book',
            'slug' => 'test-book',
            'credit_price' => 100,
            'available_copies' => 10,
            'status' => 'published',
            'pdf_filename' => 'test-book.pdf',
            'pdf_file_size' => filesize(storage_path('app/books/test-book.pdf')),
            'pdf_page_count' => count($this->pageTexts),
        ]);
    }

    private function createUserWithBook(Book $book): User
    {
        $user = User::factory()->create();

        $user->userBooks()->create([
            'book_id' => $book->id,
            'total_quantity' => 1,
        ]);

        return $user;
    }

    public function test_extract_all_pages_when_no_pages_parameter(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text");

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'total_pages' => count($this->pageTexts),
                'extracted_pages' => [1, 2, 3, 4, 5],
                'page_count' => count($this->pageTexts),
            ]);

        $text = $response->json('text');
        $this->assertNotEmpty($text);
        $this->assertStringContainsString($this->pageTexts[0], $text);
        $this->assertStringContainsString($this->pageTexts[4], $text);
    }

    public function test_extract_specific_pages(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1,3,5',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [1, 3, 5],
                'page_count' => 3,
            ]);

        $text = $response->json('text');
        $this->assertStringContainsString($this->pageTexts[0], $text);
        $this->assertStringContainsString($this->pageTexts[2], $text);
        $this->assertStringContainsString($this->pageTexts[4], $text);
        $this->assertStringNotContainsString($this->pageTexts[1], $text);
    }

    public function test_extract_page_ranges(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '2-4',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [2, 3, 4],
                'page_count' => 3,
            ]);
    }

    public function test_extract_mixed_pages_and_ranges(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1,3-4,5',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [1, 3, 4, 5],
                'page_count' => 4,
            ]);
    }

    public function test_whitespace_handling(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => ' 1 , 3 - 4 , 5 ',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [1, 3, 4, 5],
            ]);
    }

    public function test_invalid_characters_rejected(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1,abc,3',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Invalid page format. Use only numbers, commas, and hyphens.',
            ]);
    }

    public function test_invalid_range_format_multiple_hyphens(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1-2-3',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
            ])
            ->assertJsonPath('message', fn ($message) => str_contains($message, 'Invalid range format'));
    }

    public function test_invalid_range_leading_hyphen(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '-3',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_invalid_range_trailing_hyphen(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '3-',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_invalid_range_start_greater_than_end(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '4-2',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Invalid range (start > end): 4-2',
            ]);
    }

    public function test_page_exceeds_total_pages(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '10',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Page 10 exceeds total pages (5)',
            ]);
    }

    public function test_negative_page_number(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '-5',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_zero_page_number(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '0',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Page numbers must be positive: 0',
            ]);
    }

    public function test_empty_segments_rejected(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1,,3',
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Invalid page selection: empty segments are not allowed.',
            ]);
    }

    public function test_too_many_pages_requested(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $pages = implode(',', array_fill(0, 210, '1-5')); // 1050 page entries

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => $pages,
        ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Cannot extract more than 1000 pages per request',
            ]);
    }

    public function test_empty_pages_parameter_extracts_all(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'page_count' => count($this->pageTexts),
            ]);
    }

    public function test_whitespace_only_pages_parameter_extracts_all(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '   ',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'page_count' => count($this->pageTexts),
            ]);
    }

    public function test_unauthorized_user_cannot_extract(): void
    {
        $book = $this->createBookWithPdf();

        $response = $this->postJson("/api/books/{$book->id}/extract-text");

        $response->assertUnauthorized();
    }

    public function test_user_without_book_ownership_cannot_extract(): void
    {
        $book = $this->createBookWithPdf();
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text");

        $response->assertForbidden()
            ->assertJson([
                'success' => false,
                'message' => "You don't have permission to access this book",
            ]);
    }

    public function test_admin_can_extract_without_ownership(): void
    {
        $book = $this->createBookWithPdf();
        $admin = User::factory()->create(['role' => 'admin']);

        Sanctum::actingAs($admin);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1,2',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [1, 2],
            ]);
    }

    public function test_book_without_pdf_returns_404(): void
    {
        $category = Category::create([
            'name' => 'Test Category',
            'slug' => 'test-category-2',
        ]);

        $book = Book::create([
            'category_id' => $category->id,
            'title' => 'Book Without PDF',
            'slug' => 'book-without-pdf',
            'credit_price' => 100,
            'available_copies' => 10,
            'status' => 'published',
            'pdf_filename' => null,
        ]);

        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text");

        $response->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'Book has no PDF file',
            ]);
    }

    public function test_duplicate_pages_are_removed(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1,2,2,3,3,3',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [1, 2, 3],
                'page_count' => 3,
            ]);
    }

    public function test_pages_are_sorted(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        $response = $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '5,1,3,2',
        ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'extracted_pages' => [1, 2, 3, 5],
            ]);
    }

    public function test_rate_limiting(): void
    {
        $book = $this->createBookWithPdf();
        $user = $this->createUserWithBook($book);

        Sanctum::actingAs($user);

        for ($i = 0; $i < 10; $i++) {
            $this->postJson("/api/books/{$book->id}/extract-text", [
                'pages' => '1',
            ])->assertOk();
        }

        $this->postJson("/api/books/{$book->id}/extract-text", [
            'pages' => '1',
        ])->assertStatus(429);
    }
}
