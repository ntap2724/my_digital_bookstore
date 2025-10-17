<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BookReview extends Model
{
    use HasFactory;

    protected $fillable = [
        'book_id',
        'user_id',
        'rating',
        'title',
        'comment',
        'helpful_count',
        'not_helpful_count',
    ];

    protected $casts = [
        'rating' => 'integer',
        'helpful_count' => 'integer',
        'not_helpful_count' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    protected $appends = ['user_vote'];

    /**
     * Get the book that owns the review
     */
    public function book(): BelongsTo
    {
        return $this->belongsTo(Book::class);
    }

    /**
     * Get the user that owns the review
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the votes for the review
     */
    public function votes(): HasMany
    {
        return $this->hasMany(ReviewVote::class, 'review_id');
    }

    /**
     * Get current authenticated user's vote
     */
    public function getUserVoteAttribute(): ?string
    {
        if (!auth()->check()) {
            return null;
        }

        $vote = $this->votes()
            ->where('user_id', auth()->id())
            ->first();

        return $vote ? $vote->vote_type : null;
    }

    /**
     * Update vote counts from database
     */
    public function updateVoteCounts(): void
    {
        $this->helpful_count = $this->votes()->where('vote_type', 'like')->count();
        $this->not_helpful_count = $this->votes()->where('vote_type', 'dislike')->count();
        $this->saveQuietly(); // Save without triggering events
    }

    /**
     * Scope to include vote counts
     */
    public function scopeWithVoteCounts($query)
    {
        return $query->withCount([
            'votes as helpful_count' => function ($query) {
                $query->where('vote_type', 'like');
            },
            'votes as not_helpful_count' => function ($query) {
                $query->where('vote_type', 'dislike');
            },
        ]);
    }

    /**
     * Transform for API response
     */
    public function toArray()
    {
        $array = parent::toArray();
        
        // Include user info
        if ($this->relationLoaded('user')) {
            $array['user'] = [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'email' => $this->user->email,
            ];
        }

        return $array;
    }
}
