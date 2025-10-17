<?php

// ========================================
// app/Models/ReviewVote.php
// ========================================

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReviewVote extends Model
{
    use HasFactory;

    protected $fillable = [
        'review_id',
        'user_id',
        'vote_type',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Boot method to handle events
     */
    protected static function boot()
    {
        parent::boot();

        // Update counts when vote is created
        static::created(function ($vote) {
            $vote->review->updateVoteCounts();
        });

        // Update counts when vote is updated
        static::updated(function ($vote) {
            $vote->review->updateVoteCounts();
        });

        // Update counts when vote is deleted
        static::deleted(function ($vote) {
            $vote->review->updateVoteCounts();
        });
    }

    /**
     * Get the review that owns the vote
     */
    public function review(): BelongsTo
    {
        return $this->belongsTo(BookReview::class, 'review_id');
    }

    /**
     * Get the user that owns the vote
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Scope to filter by vote type
     */
    public function scopeLikes($query)
    {
        return $query->where('vote_type', 'like');
    }

    /**
     * Scope to filter by vote type
     */
    public function scopeDislikes($query)
    {
        return $query->where('vote_type', 'dislike');
    }
}