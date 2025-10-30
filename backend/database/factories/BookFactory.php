<?php

namespace Database\Factories;

use App\Models\Book;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Book>
 */
class BookFactory extends Factory
{
    protected $model = Book::class;

    public function definition(): array
    {
        $title = $this->faker->sentence(3);

        return [
            'category_id' => null,
            'title' => $title,
            'slug' => null,
            'subtitle' => $this->faker->optional()->sentence(6),
            'description' => $this->faker->paragraphs(2, true),
            'credit_price' => $this->faker->numberBetween(0, 100),
            'available_copies' => $this->faker->numberBetween(0, 50),
            'isbn' => $this->faker->isbn13(),
            'language' => $this->faker->languageCode(),
            'cover_image_url' => $this->faker->imageUrl(),
            'pdf_filename' => null,
            'pdf_file_size' => null,
            'pdf_page_count' => null,
            'published_at' => $this->faker->dateTimeBetween('-2 years', 'now'),
            'status' => 'published',
            'tags' => [],
        ];
    }
}
