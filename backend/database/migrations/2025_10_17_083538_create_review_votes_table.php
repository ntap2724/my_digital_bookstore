<?php

// database/migrations/2024_xx_xx_create_review_votes_table.php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Create review_votes table
        Schema::create('review_votes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('review_id')
                ->constrained('book_reviews')
                ->onDelete('cascade');
            $table->foreignId('user_id')
                ->constrained('users')
                ->onDelete('cascade');
            $table->enum('vote_type', ['like', 'dislike']);
            $table->timestamps();

            // Unique constraint: One vote per user per review
            $table->unique(['review_id', 'user_id'], 'unique_review_user_vote');
            
            // Indexes for performance
            $table->index('review_id');
            $table->index('user_id');
            $table->index(['review_id', 'vote_type']);
        });

        // 2. Add cached counts to book_reviews table
        Schema::table('book_reviews', function (Blueprint $table) {
            $table->integer('helpful_count')->default(0)->after('comment');
            $table->integer('not_helpful_count')->default(0)->after('helpful_count');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('review_votes');
        
        Schema::table('book_reviews', function (Blueprint $table) {
            $table->dropColumn(['helpful_count', 'not_helpful_count']);
        });
    }
};