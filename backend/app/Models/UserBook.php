<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserBook extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'book_id',
        'order_id',
        'first_purchased_at',
        'last_purchased_at',
        'last_opened_at',
    ];

    protected $casts = [
        'first_purchased_at' => 'datetime',
        'last_purchased_at' => 'datetime',
        'last_opened_at' => 'datetime',
    ];

    /**
     * @return BelongsTo<User, UserBook>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return BelongsTo<Book, UserBook>
     */
    public function book(): BelongsTo
    {
        return $this->belongsTo(Book::class);
    }

    /**
     * @return BelongsTo<Order, UserBook>
     */
    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}
