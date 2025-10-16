<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Author;
use App\Models\Book;
use App\Models\BookReview;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class BookController extends Controller
{
    public function index(Request $request)
    {
        $perPage = (int) $request->input('per_page', 12);
        $perPage = max(1, min($perPage, 100));

        $currentUser = $request->user();

        $query = Book::query()->with(['category', 'authors'])->latest('published_at')->latest('id');

        if ($currentUser) {
            $query->withExists([
                'userBooks as owned' => fn ($q) => $q->where('user_id', $currentUser->id),
            ]);
        }

        if ($search = $request->string('search')->trim()->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                    ->orWhere('subtitle', 'like', "%{$search}%")
                    ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        if ($categoryId = $request->integer('category_id')) {
            $query->where('category_id', $categoryId);
        }

        if ($authorId = $request->integer('author_id')) {
            $query->whereHas('authors', fn ($q) => $q->where('authors.id', $authorId));
        }

        if ($status = $request->string('status')->trim()->toString()) {
            $query->where('status', $status);
        }

        $paginator = $query->paginate($perPage)->appends($request->query());

        return response()->json([
            'data' => $paginator->getCollection()->map(fn (Book $book) => $this->transform($book, currentUser: $currentUser)),
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
        $book->loadMissing(['category', 'authors', 'reviews.user']);

        $currentUser = $request->user();

        return response()->json([
            'data' => $this->transform($book, includeReviews: true, currentUser: $currentUser),
        ]);
    }

    public function store(Request $request)
    {
        Gate::authorize('admin');

        $validated = $this->validatePayload($request);
        $authors = $validated['authors'] ?? [];
        unset($validated['authors']);

        $book = null;

        DB::transaction(function () use (&$book, $validated, $authors): void {
            $book = Book::create($validated);
            if (! empty($authors)) {
                $book->authors()->sync($authors);
            }
        });

        $book?->load(['category', 'authors']);

        return response()->json([
            'data' => $this->transform($book),
        ], 201);
    }

    public function update(Request $request, Book $book)
    {
        Gate::authorize('admin');

        $validated = $this->validatePayload($request, $book);
        $authors = $validated['authors'] ?? null;
        unset($validated['authors']);

        DB::transaction(function () use ($book, $validated, $authors): void {
            if (! empty($validated)) {
                $book->fill($validated)->save();
            }

            if (is_array($authors)) {
                $book->authors()->sync($authors);
            }
        });

        $book->load(['category', 'authors']);

        return response()->json([
            'data' => $this->transform($book),
        ]);
    }

    public function destroy(Book $book)
    {
        Gate::authorize('admin');

        if ($book->orderItems()->exists()) {
            return response()->json([
                'message' => 'Cannot delete book that exists in orders.',
            ], 422);
        }

        DB::transaction(function () use ($book): void {
            $book->authors()->detach();
            $book->delete();
        });

        return response()->json([
            'message' => 'Book deleted',
        ]);
    }

    private function validatePayload(Request $request, ?Book $book = null): array
    {
        $statusRule = Rule::in(['draft', 'published', 'archived']);

        return $request->validate([
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'title' => [$book ? 'sometimes' : 'required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', Rule::unique('books')->ignore($book?->id)],
            'subtitle' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'credit_price' => [$book ? 'sometimes' : 'required', 'integer', 'min:0'],
            'available_copies' => [$book ? 'sometimes' : 'required', 'integer', 'min:0'],
            'isbn' => ['nullable', 'string', 'max:50'],
            'language' => ['nullable', 'string', 'max:16'],
            'cover_image_url' => ['nullable', 'string', 'max:2048'],
            'file_url' => ['nullable', 'string', 'max:2048'],
            'published_at' => ['nullable', 'date'],
            'status' => [$book ? 'sometimes' : 'required', 'string', $statusRule],
            'authors' => ['nullable', 'array'],
            'authors.*' => ['integer', 'exists:authors,id'],
        ]);
    }

    private function transform(?Book $book, bool $includeReviews = false, ?User $currentUser = null): array
    {
        if (! $book) {
            return [];
        }

        $book->loadMissing(['category', 'authors']);

        $counts = $book->reviews()
            ->selectRaw('rating, COUNT(*) as total')
            ->groupBy('rating')
            ->pluck('total', 'rating')
            ->map(fn ($value) => (int) $value);

        $total = (int) $counts->sum();
        $average = $total > 0 ? round((float) $book->reviews()->avg('rating'), 2) : 0.0;

        $ratingSummary = [
            'average' => $average,
            'count' => $total,
            'breakdown' => [
                1 => (int) ($counts[1] ?? 0),
                2 => (int) ($counts[2] ?? 0),
                3 => (int) ($counts[3] ?? 0),
                4 => (int) ($counts[4] ?? 0),
                5 => (int) ($counts[5] ?? 0),
            ],
        ];

        $reviewsData = null;

        if ($includeReviews) {
            $reviews = $book->relationLoaded('reviews')
                ? $book->reviews
                : $book->reviews()->with(['user:id,name'])->latest()->get();

            $reviewsData = $reviews->map(static function (BookReview $review) {
                return [
                    'id' => $review->id,
                    'rating' => (int) $review->rating,
                    'comment' => $review->comment,
                    'created_at' => optional($review->created_at)->toISOString(),
                    'user' => $review->user?->only(['id', 'name']),
                ];
            })->values()->all();
        }

        return [
            'id' => $book->id,
            'title' => $book->title,
            'slug' => $book->slug,
            'subtitle' => $book->subtitle,
            'description' => $book->description,
            'credit_price' => (int) $book->credit_price,
            'available_copies' => (int) $book->available_copies,
            'isbn' => $book->isbn,
            'language' => $book->language,
            'cover_image_url' => $book->cover_image_url,
            'file_url' => $book->file_url,
            'published_at' => optional($book->published_at)->toISOString(),
            'status' => $book->status,
            'tags' => $book->tags ?? [],
            'category' => $book->category?->only(['id', 'name', 'slug', 'description']),
            'authors' => $book->authors->map(fn (Author $author) => [
                'id' => $author->id,
                'name' => $author->name,
                'slug' => $author->slug,
                'bio' => $author->bio,
            ])->values(),
            'rating_summary' => $ratingSummary,
            'reviews' => $includeReviews ? $reviewsData : null,
            'owned' => $this->bookOwnedBy($book, $currentUser),
        ];
    }

    private function bookOwnedBy(Book $book, ?User $currentUser): bool
    {
        if (! $currentUser) {
            return false;
        }

        $ownedAttribute = $book->getAttribute('owned');
        if ($ownedAttribute !== null) {
            return (bool) $ownedAttribute;
        }

        if ($book->relationLoaded('userBooks')) {
            return $book->userBooks->contains('user_id', $currentUser->id);
        }

        return $book->userBooks()
            ->where('user_id', $currentUser->id)
            ->exists();
    }
}


