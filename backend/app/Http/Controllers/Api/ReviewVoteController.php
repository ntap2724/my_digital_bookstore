<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BookReview;
use App\Models\ReviewVote;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

class ReviewVoteController extends Controller
{
    /**
     * Vote on a review (like or dislike)
     *
     * @param Request $request
     * @param int $reviewId
     * @return JsonResponse
     */
    public function vote(Request $request, int $reviewId): JsonResponse
    {
        $request->validate([
            'vote_type' => ['required', Rule::in(['like', 'dislike'])],
        ]);

        $review = BookReview::findOrFail($reviewId);
        $userId = Auth::id();

        // Prevent self-voting
        if ($review->user_id === $userId) {
            return response()->json([
                'error' => 'Cannot vote on your own review',
            ], 403);
        }

        $voteType = $request->input('vote_type');

        // Check for existing vote
        $existingVote = ReviewVote::where('review_id', $reviewId)
            ->where('user_id', $userId)
            ->first();

        if ($existingVote) {
            // If same vote type - remove (toggle off)
            if ($existingVote->vote_type === $voteType) {
                $existingVote->delete();

                return response()->json([
                    'success' => true,
                    'action' => 'removed',
                    'helpful_count' => $review->fresh()->helpful_count,
                    'not_helpful_count' => $review->fresh()->not_helpful_count,
                    'user_vote' => null,
                ]);
            }

            // Different vote type - update
            $existingVote->update(['vote_type' => $voteType]);

            return response()->json([
                'success' => true,
                'action' => 'updated',
                'helpful_count' => $review->fresh()->helpful_count,
                'not_helpful_count' => $review->fresh()->not_helpful_count,
                'user_vote' => $voteType,
            ]);
        }

        // Create new vote
        ReviewVote::create([
            'review_id' => $reviewId,
            'user_id' => $userId,
            'vote_type' => $voteType,
        ]);

        return response()->json([
            'success' => true,
            'action' => 'created',
            'helpful_count' => $review->fresh()->helpful_count,
            'not_helpful_count' => $review->fresh()->not_helpful_count,
            'user_vote' => $voteType,
        ], 201);
    }

    /**
     * Remove user's vote from a review
     *
     * @param int $reviewId
     * @return JsonResponse
     */
    public function removeVote(int $reviewId): JsonResponse
    {
        $review = BookReview::findOrFail($reviewId);
        $userId = Auth::id();

        $vote = ReviewVote::where('review_id', $reviewId)
            ->where('user_id', $userId)
            ->first();

        if (!$vote) {
            return response()->json([
                'error' => 'Vote not found',
            ], 404);
        }

        $vote->delete();

        return response()->json([
            'success' => true,
            'helpful_count' => $review->fresh()->helpful_count,
            'not_helpful_count' => $review->fresh()->not_helpful_count,
            'user_vote' => null,
        ]);
    }

    /**
     * Get vote status for a review
     *
     * @param int $reviewId
     * @return JsonResponse
     */
    public function getVoteStatus(int $reviewId): JsonResponse
    {
        $review = BookReview::findOrFail($reviewId);
        $userId = Auth::id();

        $userVote = null;
        if ($userId) {
            $vote = ReviewVote::where('review_id', $reviewId)
                ->where('user_id', $userId)
                ->first();
            $userVote = $vote ? $vote->vote_type : null;
        }

        return response()->json([
            'review_id' => $reviewId,
            'helpful_count' => $review->helpful_count,
            'not_helpful_count' => $review->not_helpful_count,
            'user_vote' => $userVote,
        ]);
    }
}