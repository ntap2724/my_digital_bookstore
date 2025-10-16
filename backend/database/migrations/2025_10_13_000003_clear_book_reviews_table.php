<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::table('book_reviews')->truncate();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // no-op; existing reviews were intentionally removed.
    }
};
