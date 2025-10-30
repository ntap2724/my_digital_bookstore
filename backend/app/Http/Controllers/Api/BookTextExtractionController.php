<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Services\PdfTextExtractor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use RuntimeException;

class BookTextExtractionController extends Controller
{
    public function __construct(private readonly PdfTextExtractor $extractor)
    {
    }

    public function __invoke(Request $request, Book $book): JsonResponse
    {
        $user = $request->user();

        if (! $user) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized',
            ], 401);
        }

        $isAdmin = $user->role === 'admin';
        $ownsBook = DB::table('user_books')
            ->where('user_id', $user->id)
            ->where('book_id', $book->id)
            ->exists();

        if (! $isAdmin && ! $ownsBook) {
            return response()->json([
                'success' => false,
                'message' => "You don't have permission to access this book",
            ], 403);
        }

        if (! $book->hasPdf()) {
            return response()->json([
                'success' => false,
                'message' => 'Book has no PDF file',
            ], 404);
        }

        $validated = $request->validate([
            'pages' => 'nullable|string|max:10000',
        ]);

        $pdfPath = $book->getPdfPath();

        if (! $pdfPath || ! is_readable($pdfPath)) {
            return response()->json([
                'success' => false,
                'message' => 'Book has no PDF file',
            ], 404);
        }

        try {
            $document = $this->extractor->parseDocument($pdfPath);
            $totalPages = count($document->getPages());

            $pageNumbers = $this->extractor->parsePageSelection($validated['pages'] ?? null, $totalPages);

            $result = $this->extractor->extractFromDocument($document, $pageNumbers);

            if ($book->pdf_page_count !== $result['total_pages']) {
                $book->pdf_page_count = $result['total_pages'];
                $book->save();
            }

            return response()->json([
                'success' => true,
                'text' => $result['text'],
                'total_pages' => $result['total_pages'],
                'extracted_pages' => $result['extracted_pages'],
                'page_count' => $result['page_count'],
            ]);
        } catch (InvalidArgumentException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], 400);
        } catch (RuntimeException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], 500);
        } catch (\Throwable $exception) {
            report($exception);

            return response()->json([
                'success' => false,
                'message' => 'Text extraction failed',
            ], 500);
        }
    }
}
