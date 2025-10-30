<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AuthorController;
use App\Http\Controllers\Api\BookController;
use App\Http\Controllers\Api\BookReviewController;
use App\Http\Controllers\Api\BookTextExtractionController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ChangePasswordController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\UserBookController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\WalletTopUpRequestController;
use App\Http\Controllers\Api\ReviewVoteController;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

Route::get('/categories', [CategoryController::class, 'index']);
Route::get('/categories/{category}', [CategoryController::class, 'show']);

Route::get('/authors', [AuthorController::class, 'index']);
Route::get('/authors/{author}', [AuthorController::class, 'show']);

Route::get('/email-exists', function (Request $request) {
    $email = $request->query('email');

    if (! $email || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return response()->json([
            'exists' => false,
            'name' => null,
        ]);
    }

    $user = User::query()
        ->where('email', $email)
        ->select(['name'])
        ->first();

    return response()->json([
        'exists' => (bool) $user,
        'name' => optional($user)->name,
    ]);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/change-password', ChangePasswordController::class);

    Route::get('/user', fn (Request $request) => $request->user());

    Route::put('/user', function (Request $request) {
        $user = $request->user();
        $minDob = now()->subYears(13)->toDateString();

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'phone' => ['sometimes', 'required', 'string', 'regex:/^(0|\\+84)(\\d{9})$/'],
            'dob' => ['sometimes', 'required', 'date', 'before_or_equal:'.$minDob],
            'gender' => ['sometimes', 'required', 'string', 'in:male,female,other'],
        ]);

        if (isset($data['name'])) {
            $user->name = $data['name'];
        }

        if (isset($data['phone'])) {
            $user->phone = $data['phone'];
        }

        if (isset($data['dob'])) {
            $user->dob = $data['dob'];
        }

        if (isset($data['gender'])) {
            $user->gender = $data['gender'];
        }

        $user->save();

        return $user->fresh();
    });

    Route::delete('/user', function (Request $request) {
        $user = $request->user();

        if ($user?->role === 'admin') {
            return response()->json([
                'message' => 'Admins cannot delete their own account.',
            ], 422);
        }

        if ($user) {
            $user->tokens()->delete();
            $user->delete();
        }

        return response()->json([
            'message' => 'Account deleted',
        ]);
    });

    Route::apiResource('users', UserController::class)->except(['create', 'edit']);

    Route::post('/categories', [CategoryController::class, 'store']);
    Route::put('/categories/{category}', [CategoryController::class, 'update']);
    Route::delete('/categories/{category}', [CategoryController::class, 'destroy']);

    Route::post('/authors', [AuthorController::class, 'store']);
    Route::put('/authors/{author}', [AuthorController::class, 'update']);
    Route::delete('/authors/{author}', [AuthorController::class, 'destroy']);

    Route::get('/books', [BookController::class, 'index']);
    Route::get('/books/{book}', [BookController::class, 'show']);
    Route::get('/books/{book}/reviews', [BookReviewController::class, 'index']);
    Route::get('/books/{book}/my-review', [BookReviewController::class, 'getUserReview']);
    Route::post('/books', [BookController::class, 'store']);
    Route::put('/books/{book}', [BookController::class, 'update']);
    Route::delete('/books/{book}', [BookController::class, 'destroy']);
    
    // PDF upload (Admin only)
    Route::post('/books/{book}/pdf', [BookController::class, 'uploadPdf']);
    
    // PDF delete (Admin only)
    Route::delete('/books/{book}/pdf', [BookController::class, 'deletePdf']);
    
    // PDF download (User must own the book)
    Route::post('/books/{book}/ask', [BookController::class, 'askQuestion']);
    Route::get('/books/{book}/pdf', [BookController::class, 'downloadPdf']);
    Route::post('/books/{book}/extract-text', BookTextExtractionController::class)
        ->middleware('throttle:10,1');

    Route::post('/books/{book}/reviews', [BookReviewController::class, 'store']);
    Route::delete('/books/{book}/reviews/{review}', [BookReviewController::class, 'destroy']);

    Route::get('/orders', [OrderController::class, 'index']);
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::post('/orders', [OrderController::class, 'store']);
    Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel']);

    Route::get('/my-books', [UserBookController::class, 'index']);
    Route::get('/my-books/{book}', [UserBookController::class, 'show']);
    Route::post('/my-books/{book}/opened', [UserBookController::class, 'markOpened']);

    Route::get('/wallet', [WalletController::class, 'current']);
    Route::get('/wallet/transactions', [WalletController::class, 'currentTransactions']);
    Route::get('/wallet/top-ups', [WalletTopUpRequestController::class, 'index']);
    Route::post('/wallet/top-ups', [WalletTopUpRequestController::class, 'store']);
    Route::get('/wallet/top-ups/{walletTopUp}', [WalletTopUpRequestController::class, 'show']);
    Route::post('/wallet/top-ups/{walletTopUp}/approve', [WalletTopUpRequestController::class, 'approve']);
    Route::post('/wallet/top-ups/{walletTopUp}/reject', [WalletTopUpRequestController::class, 'reject']);

    Route::get('/wallets', [WalletController::class, 'index']);
    Route::get('/wallets/{user}', [WalletController::class, 'showForUser']);
    Route::get('/wallets/{user}/transactions', [WalletController::class, 'transactionsForUser']);
    Route::post('/wallets/{user}/adjust', [WalletController::class, 'adjust']);
});

// Review Vote Routes (requires authentication)
Route::middleware('auth:sanctum')->group(function () {
    // Vote on a review
    Route::post('/reviews/{reviewId}/vote', [ReviewVoteController::class, 'vote']);
    
    // Remove vote from a review
    Route::delete('/reviews/{reviewId}/vote', [ReviewVoteController::class, 'removeVote']);
    
    // Get vote status (can be optional auth too)
    Route::get('/reviews/{reviewId}/vote', [ReviewVoteController::class, 'getVoteStatus']);
});

// Book Review Routes
Route::prefix('books/{book}')->group(function () {
    // Get all reviews for a book (optional auth to include user votes)
    Route::get('/reviews', [BookReviewController::class, 'index']);
    
    // Routes requiring authentication
    Route::middleware('auth:sanctum')->group(function () {
        // Get current user's review
        Route::get('/reviews/user', [BookReviewController::class, 'getUserReview']);
        
        // Submit a new review
        Route::post('/reviews', [BookReviewController::class, 'store']);
        
        // Update a review
        Route::put('/reviews/{review}', [BookReviewController::class, 'update']);

        // Delete a review
        Route::delete('/reviews/{review}', [BookReviewController::class, 'destroy']);
    });
});
