<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Models\BookReview;
use App\Models\UserBook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class BookReviewController extends Controller
{
    public function index(Book $book)
    {
        $reviews = $book->reviews()
            ->with(['user:id,name'])
            ->latest()
            ->paginate((int) request('per_page', 10));

        return response()->json([
            'data' => $reviews->getCollection()->map(static function (BookReview $review) {
                return [
                    'id' => $review->id,
                    'rating' => (int) $review->rating,
                    'comment' => $review->comment,
                    'created_at' => optional($review->created_at)->toISOString(),
                    'user' => $review->user?->only(['id', 'name']),
                ];
            })->values(),
            'meta' => [
                'current_page' => $reviews->currentPage(),
                'last_page' => $reviews->lastPage(),
                'per_page' => $reviews->perPage(),
                'total' => $reviews->total(),
            ],
        ]);
    }

    public function store(Request $request, Book $book)
    {
        $user = $request->user();

        if (! $user) {
            return response()->json([
                'message' => 'Authentication required.',
            ], 401);
        }

        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        $ownsBook = UserBook::query()
            ->where('user_id', $user->id)
            ->where('book_id', $book->id)
            ->exists();

        if (! $ownsBook) {
            return response()->json([
                'message' => 'You must purchase this book before leaving a review.',
            ], 422);
        }

        $review = BookReview::updateOrCreate(
            [
                'book_id' => $book->id,
                'user_id' => $user->id,
            ],
            [
                'rating' => $data['rating'],
                'comment' => $data['comment'] ?? null,
            ]
        );

        $review->load('user:id,name');

        return response()->json([
            'data' => [
                'id' => $review->id,
                'rating' => (int) $review->rating,
                'comment' => $review->comment,
                'created_at' => optional($review->created_at)->toISOString(),
                'user' => $review->user?->only(['id', 'name']),
            ],
        ], 201);
    }

    public function destroy(Request $request, Book $book, BookReview $review)
    {
        if ($review->book_id !== $book->id) {
            return response()->json(['message' => 'Review not found for this book.'], 404);
        }

        $user = $request->user();
        $isAdmin = $user && Gate::forUser($user)->allows('admin');

        if (! $user || (! $isAdmin && $review->user_id !== $user->id)) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        $review->delete();

        return response()->json(['message' => 'Review deleted']);
    }
}
