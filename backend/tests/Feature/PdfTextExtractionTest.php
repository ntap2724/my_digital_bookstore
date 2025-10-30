<?php

namespace Tests\Feature;

use App\Models\Book;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PdfTextExtractionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('books');
    }

    public function test_unauthenticated_user_cannot_extract_text(): void
    {
        $book = Book::factory()->create();

        $response = $this->postJson("/api/books/{$book->id}/extract-text");

        $response->assertStatus(401);
    }

    public function test_user_cannot_extract_text_from_book_they_dont_own(): void
    {
        $user = User::factory()->create();
        $book = Book::factory()->create([
            'pdf_filename' => 'test.pdf',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/books/{$book->id}/extract-text");

        $response->assertStatus(403)
            ->assertJson([
                'message' => 'You must own this book to extract text',
            ]);
    }

    public function test_cannot_extract_text_from_book_without_pdf(): void
    {
        $user = User::factory()->create();
        $book = Book::factory()->create([
            'pdf_filename' => null,
        ]);
        
        $book->userBooks()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/books/{$book->id}/extract-text");

        $response->assertStatus(404)
            ->assertJson([
                'message' => 'PDF file not available for this book',
            ]);
    }

    public function test_can_extract_text_from_owned_book_pdf(): void
    {
        $user = User::factory()->create();
        
        $pdfContent = $this->createSimplePdf();
        $filename = 'test_book.pdf';
        Storage::disk('books')->put($filename, $pdfContent);
        
        $book = Book::factory()->create([
            'pdf_filename' => $filename,
        ]);
        
        $book->userBooks()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/books/{$book->id}/extract-text");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'success',
                'text',
                'pages',
            ])
            ->assertJson([
                'success' => true,
            ]);
        
        $this->assertNotEmpty($response->json('text'));
    }

    public function test_handles_pdf_with_no_text_content(): void
    {
        $user = User::factory()->create();
        
        $pdfContent = $this->createMinimalPdfWithoutText();
        $filename = 'empty_book.pdf';
        Storage::disk('books')->put($filename, $pdfContent);
        
        $book = Book::factory()->create([
            'pdf_filename' => $filename,
        ]);
        
        $book->userBooks()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/books/{$book->id}/extract-text");

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);
        
        $this->assertStringContainsString('No text content found', $response->json('message'));
    }

    private function createSimplePdf(): string
    {
        return $this->buildPdfWithText('Hello from test PDF');
    }

    private function createMinimalPdfWithoutText(): string
    {
        return $this->buildPdfWithText('', includeText: false);
    }

    private function buildPdfWithText(string $text, bool $includeText = true): string
    {
        $objects = [];

        $objects[1] = "<<\n/Type /Catalog\n/Pages 2 0 R\n>>\n";
        $objects[2] = "<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\n";

        if ($includeText) {
            $objects[3] = "<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n/Resources <<\n/Font << /F1 5 0 R >>\n>>\n/Contents 4 0 R\n>>\n";

            $streamContent = "BT\n/F1 12 Tf\n72 720 Td\n(".$this->escapePdfText($text).") Tj\nET\n";
            $objects[4] = "<<\n/Length ".strlen($streamContent)."\n>>\nstream\n{$streamContent}endstream\n";
            $objects[5] = "<<\n/Type /Font\n/Subtype /Type1\n/BaseFont /Helvetica\n>>\n";
        } else {
            $objects[3] = "<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n>>\n";
        }

        $orderedObjects = [];
        $maxIndex = max(array_keys($objects));
        for ($i = 1; $i <= $maxIndex; $i++) {
            if (! isset($objects[$i])) {
                continue;
            }

            $orderedObjects[$i] = sprintf("%d 0 obj\n%sendobj\n", $i, $objects[$i]);
        }

        $pdf = "%PDF-1.4\n";
        $offsetEntries = [];
        $offsetEntries[] = sprintf("%010d 65535 f ", 0);

        foreach ($orderedObjects as $object) {
            $offsetEntries[] = sprintf("%010d 00000 n ", strlen($pdf));
            $pdf .= $object."\n";
        }

        $xrefPosition = strlen($pdf);
        $pdf .= "xref\n0 ".count($offsetEntries)."\n";
        $pdf .= implode("\n", $offsetEntries)."\n";
        $pdf .= "trailer\n<<\n/Size ".count($offsetEntries)."\n/Root 1 0 R\n>>\n";
        $pdf .= "startxref\n{$xrefPosition}\n%%EOF\n";

        return $pdf;
    }

    private function escapePdfText(string $text): string
    {
        $text = str_replace('\\', '\\\\', $text);
        $text = str_replace('(', '\\(', $text);
        $text = str_replace(')', '\\)', $text);
        return $text;
    }
}
