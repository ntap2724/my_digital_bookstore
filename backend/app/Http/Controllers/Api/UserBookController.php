<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Models\UserBook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpKernel\Exception\HttpException;

class UserBookController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        if (! $user) {
            throw new HttpException(401, 'Authentication required');
        }

        $perPage = (int) $request->input('per_page', 12);
        $perPage = max(1, min($perPage, 100));

        $query = UserBook::query()
            ->with(['book.authors', 'book.category'])
            ->where('user_id', $user->id)
            ->latest('last_purchased_at')
            ->latest('id');

        $paginator = $query->paginate($perPage)->appends($request->query());

        return response()->json([
            'data' => $paginator->getCollection()->map(fn (UserBook $userBook) => $this->transform($userBook)),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function show(Request $request, Book $book)
    {
        $user = $request->user();
        if (! $user) {
            throw new HttpException(401, 'Authentication required');
        }

        $userBook = UserBook::query()
            ->with(['book.authors', 'book.category'])
            ->where('user_id', $user->id)
            ->where('book_id', $book->id)
            ->firstOrFail();

        return response()->json([
            'data' => $this->transform($userBook),
        ]);
    }

    public function markOpened(Request $request, Book $book)
    {
        $user = $request->user();
        if (! $user) {
            throw new HttpException(401, 'Authentication required');
        }

        $userBook = UserBook::query()
            ->where('user_id', $user->id)
            ->where('book_id', $book->id)
            ->lockForUpdate()
            ->firstOrFail();

        $userBook->last_opened_at = now();
        $userBook->save();

        $userBook->loadMissing(['book.authors', 'book.category']);

        return response()->json([
            'data' => $this->transform($userBook),
        ]);
    }

    private function transform(UserBook $userBook): array
    {
        $book = $userBook->book;

        return [
            'id' => $userBook->id,
            'user_id' => $userBook->user_id,
            'book_id' => $userBook->book_id,
            'order_id' => $userBook->order_id,
            'first_purchased_at' => optional($userBook->first_purchased_at)->toISOString(),
            'last_purchased_at' => optional($userBook->last_purchased_at)->toISOString(),
            'last_opened_at' => optional($userBook->last_opened_at)->toISOString(),
            'book' => $book ? [
                'id' => $book->id,
                'title' => $book->title,
                'slug' => $book->slug,
                'subtitle' => $book->subtitle,
                'description' => $book->description,
                'credit_price' => (int) $book->credit_price,
                'isbn' => $book->isbn,
                'language' => $book->language,
                'cover_image_url' => $book->cover_image_url,
                'pdf_filename' => $book->pdf_filename,
                'pdf_file_size' => $book->pdf_file_size,
                'pdf_page_count' => $book->pdf_page_count,
                'published_at' => optional($book->published_at)->toISOString(),
                'status' => $book->status,
                'category' => $book->category?->only(['id', 'name']),
                'authors' => $book->authors->map(fn ($author) => $author->only(['id', 'name']))->values(),
            ] : null,
        ];
    }
}
