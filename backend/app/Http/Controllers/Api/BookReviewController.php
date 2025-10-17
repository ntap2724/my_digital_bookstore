<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Models\BookReview;
use App\Models\UserBook;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;

class BookReviewController extends Controller
{
    /**
     * Get all reviews for a book
     * ✅ UPDATED: Include vote counts and user's vote status
     */
    public function index(Book $book)
    {
        // Get paginated reviews with user info
        $reviews = $book->reviews()
            ->with('user:id,name,email')
            ->orderBy('created_at', 'desc')
            ->paginate(10);

        // Add vote counts and user's vote to each review
        $currentUserId = Auth::id();
        
        $reviewsData = $reviews->map(function ($review) use ($currentUserId) {
            $data = [
                'id' => $review->id,
                'book_id' => $review->book_id,
                'user_id' => $review->user_id,
                'rating' => (int) $review->rating,
                'title' => $review->title,
                'comment' => $review->comment,
                'helpful_count' => (int) $review->helpful_count,
                'not_helpful_count' => (int) $review->not_helpful_count,
                'created_at' => optional($review->created_at)->toIso8601String(),
                'updated_at' => optional($review->updated_at)->toIso8601String(),
                'user' => $review->user ? [
                    'id' => $review->user->id,
                    'name' => $review->user->name,
                    'email' => $review->user->email,
                ] : null,
            ];

            // Add user's vote if authenticated
            if ($currentUserId) {
                $userVote = $review->votes()
                    ->where('user_id', $currentUserId)
                    ->first();
                $data['user_vote'] = $userVote ? $userVote->vote_type : null;
            } else {
                $data['user_vote'] = null;
            }

            return $data;
        });

        // Calculate rating breakdown
        $ratingCounts = $book->reviews()
            ->selectRaw('rating, COUNT(*) as count')
            ->groupBy('rating')
            ->pluck('count', 'rating')
            ->toArray();

        // Ensure all 5 rating levels (1-5) are present
        $breakdown = [];
        for ($i = 5; $i >= 1; $i--) {
            $breakdown[$i] = $ratingCounts[$i] ?? 0;
        }

        $totalReviews = array_sum($breakdown);
        $averageRating = $totalReviews > 0
            ? $book->reviews()->avg('rating')
            : 0;

        return response()->json([
            'reviews' => $reviewsData, // ✅ Changed from 'data' to 'reviews'
            'total_reviews' => $totalReviews,
            'average_rating' => round($averageRating, 1),
            'rating_breakdown' => $breakdown,
            // Pagination meta
            'pagination' => [
                'current_page' => $reviews->currentPage(),
                'last_page' => $reviews->lastPage(),
                'per_page' => $reviews->perPage(),
                'total' => $reviews->total(),
            ],
        ]);
    }

    /**
     * Get the authenticated user's review for a specific book
     * ✅ UPDATED: Include vote counts
     */
    public function getUserReview(Book $book)
    {
        $review = $book->reviews()
            ->where('user_id', Auth::id())
            ->with('user:id,name,email')
            ->first();

        if (!$review) {
            return response()->json([
                'review' => null, // ✅ Return null instead of 404
            ]);
        }

        // Get user's own vote on their review (usually not applicable, but included for consistency)
        $userVote = $review->votes()
            ->where('user_id', Auth::id())
            ->first();

        return response()->json([
            'review' => [
                'id' => $review->id,
                'book_id' => $review->book_id,
                'user_id' => $review->user_id,
                'rating' => (int) $review->rating,
                'title' => $review->title,
                'comment' => $review->comment,
                'helpful_count' => (int) $review->helpful_count,
                'not_helpful_count' => (int) $review->not_helpful_count,
                'user_vote' => $userVote ? $userVote->vote_type : null,
                'created_at' => optional($review->created_at)->toIso8601String(),
                'updated_at' => optional($review->updated_at)->toIso8601String(),
                'user' => $review->user ? [
                    'id' => $review->user->id,
                    'name' => $review->user->name,
                    'email' => $review->user->email,
                ] : null,
            ],
        ]);
    }

    /**
     * Store a new review
     * ✅ UPDATED: Support title field and return vote counts
     */
    public function store(Request $request, Book $book)
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'message' => 'Authentication required.',
            ], 401);
        }

        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'title' => ['nullable', 'string', 'max:255'], // ✅ Add title support
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        // Check if user owns the book
        $ownsBook = UserBook::query()
            ->where('user_id', $user->id)
            ->where('book_id', $book->id)
            ->exists();

        if (!$ownsBook) {
            return response()->json([
                'message' => 'You must purchase this book before leaving a review.',
            ], 422);
        }

        // Check if user already reviewed this book
        $existingReview = BookReview::where('book_id', $book->id)
            ->where('user_id', $user->id)
            ->first();

        if ($existingReview) {
            return response()->json([
                'message' => 'You have already reviewed this book. Use update endpoint to modify it.',
            ], 409);
        }

        // Create new review
        $review = BookReview::create([
            'book_id' => $book->id,
            'user_id' => $user->id,
            'rating' => $data['rating'],
            'title' => $data['title'] ?? null,
            'comment' => $data['comment'] ?? null,
        ]);

        $review->load('user:id,name,email');

        return response()->json([
            'message' => 'Review submitted successfully',
            'review' => [
                'id' => $review->id,
                'book_id' => $review->book_id,
                'user_id' => $review->user_id,
                'rating' => (int) $review->rating,
                'title' => $review->title,
                'comment' => $review->comment,
                'helpful_count' => 0,
                'not_helpful_count' => 0,
                'user_vote' => null,
                'created_at' => optional($review->created_at)->toIso8601String(),
                'updated_at' => optional($review->updated_at)->toIso8601String(),
                'user' => $review->user ? [
                    'id' => $review->user->id,
                    'name' => $review->user->name,
                    'email' => $review->user->email,
                ] : null,
            ],
        ], 201);
    }

    /**
     * Update an existing review
     * ✅ NEW: Separate update method (better than updateOrCreate)
     */
    public function update(Request $request, Book $book, BookReview $review)
    {
        // Verify review belongs to this book
        if ($review->book_id !== $book->id) {
            return response()->json([
                'message' => 'Review not found for this book.',
            ], 404);
        }

        // Verify user owns this review
        if ($review->user_id !== $request->user()->id) {
            return response()->json([
                'message' => 'You can only update your own reviews.',
            ], 403);
        }

        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'title' => ['nullable', 'string', 'max:255'],
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        $review->update([
            'rating' => $data['rating'],
            'title' => $data['title'] ?? null,
            'comment' => $data['comment'] ?? null,
        ]);

        $review->load('user:id,name,email');

        // Get user's vote on this review
        $userVote = $review->votes()
            ->where('user_id', Auth::id())
            ->first();

        return response()->json([
            'message' => 'Review updated successfully',
            'review' => [
                'id' => $review->id,
                'book_id' => $review->book_id,
                'user_id' => $review->user_id,
                'rating' => (int) $review->rating,
                'title' => $review->title,
                'comment' => $review->comment,
                'helpful_count' => (int) $review->helpful_count,
                'not_helpful_count' => (int) $review->not_helpful_count,
                'user_vote' => $userVote ? $userVote->vote_type : null,
                'created_at' => optional($review->created_at)->toIso8601String(),
                'updated_at' => optional($review->updated_at)->toIso8601String(),
                'user' => $review->user ? [
                    'id' => $review->user->id,
                    'name' => $review->user->name,
                    'email' => $review->user->email,
                ] : null,
            ],
        ]);
    }

    /**
     * Delete a review
     * ✅ UNCHANGED: Keep existing logic
     */
    public function destroy(Request $request, Book $book, BookReview $review)
    {
        if ($review->book_id !== $book->id) {
            return response()->json([
                'message' => 'Review not found for this book.',
            ], 404);
        }

        $user = $request->user();
        $isAdmin = $user && Gate::forUser($user)->allows('admin');

        if (!$user || (!$isAdmin && $review->user_id !== $user->id)) {
            return response()->json([
                'message' => 'Forbidden',
            ], 403);
        }

        $review->delete();

        return response()->json([
            'message' => 'Review deleted successfully',
        ]);
    }
}