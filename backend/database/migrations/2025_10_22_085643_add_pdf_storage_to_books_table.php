<?php

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
        Schema::table('books', function (Blueprint $table) {
            // Add PDF storage fields
            $table->string('pdf_filename')->nullable()->after('cover_image_url');
            $table->bigInteger('pdf_file_size')->nullable()->after('pdf_filename')->comment('File size in bytes');
            $table->integer('pdf_page_count')->nullable()->after('pdf_file_size');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('books', function (Blueprint $table) {
            $table->dropColumn(['pdf_filename', 'pdf_file_size', 'pdf_page_count']);
        });
    }
};
