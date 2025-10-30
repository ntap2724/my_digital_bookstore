<?php

namespace App\Providers;

use App\Services\PdfTextExtractor;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\ServiceProvider;
use Smalot\PdfParser\Parser;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(PdfTextExtractor::class, function ($app) {
            return new PdfTextExtractor(new Parser());
        });
    }

    public function boot(): void
    {
        $this->ensureDatabaseIsReady();
    }

    private function ensureDatabaseIsReady(): void
    {
        static $checked = false;

        if ($checked || $this->app->runningInConsole()) {
            return;
        }

        if (! config('database.auto_run_migrations', false)) {
            $checked = true;

            return;
        }

        try {
            if (! Schema::hasTable('migrations')) {
                Artisan::call('migrate', ['--force' => true, '--quiet' => true]);
                $checked = true;

                return;
            }

            $ran = DB::table('migrations')->pluck('migration')->all();

            $files = collect(glob(database_path('migrations/*.php')))
                ->map(fn (string $path) => pathinfo($path, PATHINFO_FILENAME))
                ->all();

            $pending = array_diff($files, $ran);

            if (! empty($pending)) {
                Artisan::call('migrate', ['--force' => true, '--quiet' => true]);
            }
        } catch (\Throwable $exception) {
            Log::warning('Skipping automatic migration execution', [
                'exception' => $exception,
            ]);
        } finally {
            $checked = true;
        }
    }
}
