<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\\Database\\Factories\\UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'phone',
        'dob',
        'gender',
        'terms_accepted_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'role' => 'string',
            'dob' => 'date',
            'terms_accepted_at' => 'datetime',
        ];
    }

    /**
     * @return HasMany<UserBook>
     */
    public function userBooks(): HasMany
    {
        return $this->hasMany(UserBook::class);
    }

    /**
     * @return HasMany<WalletTopUpRequest>
     */
    public function walletTopUpRequests(): HasMany
    {
        return $this->hasMany(WalletTopUpRequest::class);
    }
    /**
     * Get the review votes for the user
     */
    public function reviewVotes(): HasMany
    {
        return $this->hasMany(ReviewVote::class);
    }

    /**
     * Get the reviews for the user
     */
    public function reviews(): HasMany
    {
        return $this->hasMany(BookReview::class);
    }
}
