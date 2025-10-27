<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class Book extends Model
{
    use HasFactory;

    protected $fillable = [
        'category_id',
        'title',
        'slug',
        'subtitle',
        'description',
        'credit_price',
        'available_copies',
        'isbn',
        'language',
        'cover_image_url',
        'pdf_filename',
        'pdf_file_size',
        'pdf_page_count',
        'published_at',
        'status',
        'tags',
    ];

    protected $casts = [
        'published_at' => 'datetime',
        'tags' => 'array',
        'pdf_file_size' => 'integer',
        'pdf_page_count' => 'integer',
    ];

    protected static function booted(): void
    {
        static::saving(function (Book $book): void {
            if (empty($book->slug) && ! empty($book->title)) {
                $book->slug = Str::slug($book->title);
            }
        });
    }

    /**
     * @return BelongsTo<Category, Book>
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * @return BelongsToMany<Author>
     */
    public function authors(): BelongsToMany
    {
        return $this->belongsToMany(Author::class);
    }

    /**
     * @return HasMany<OrderItem>
     */
    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /**
     * @return HasMany<BookReview>
     */
    public function reviews(): HasMany
    {
        return $this->hasMany(BookReview::class);
    }

    /**
     * @return HasMany<UserBook>
     */
    public function userBooks(): HasMany
    {
        return $this->hasMany(UserBook::class);
    }

    /**
     * Check if book has a PDF file
     */
    public function hasPdf(): bool
    {
        return !empty($this->pdf_filename) && 
               Storage::disk('books')->exists($this->pdf_filename);
    }

    /**
     * Get the full path to the PDF file
     */
    public function getPdfPath(): ?string
    {
        return $this->hasPdf() 
            ? Storage::disk('books')->path($this->pdf_filename)
            : null;
    }

    /**
     * Delete the PDF file from storage
     */
    public function deletePdf(): bool
    {
        if ($this->pdf_filename && Storage::disk('books')->exists($this->pdf_filename)) {
            return Storage::disk('books')->delete($this->pdf_filename);
        }
        return false;
    }

}

