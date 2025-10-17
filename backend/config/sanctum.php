<?php

// ========================================
// config/sanctum.php - Hybrid Configuration
// ========================================

return [

    /*
    |--------------------------------------------------------------------------
    | Stateful Domains
    |--------------------------------------------------------------------------
    |
    | Requests from these domains will receive stateful API authentication
    | cookies (for SPA). Mobile apps will use Bearer tokens instead.
    |
    */

    'stateful' => explode(',', env('SANCTUM_STATEFUL_DOMAINS', sprintf(
        '%s%s%s',
        'localhost,localhost:3000,localhost:5173,127.0.0.1,127.0.0.1:8000,::1',
        env('APP_URL') ? ','.parse_url(env('APP_URL'), PHP_URL_HOST) : '',
        Illuminate\Support\Str::endsWith(app('url')->to('/'), '.test') ? ','.app('url')->to('/') : ''
    ))),

    /*
    |--------------------------------------------------------------------------
    | Sanctum Guards
    |--------------------------------------------------------------------------
    */

    'guard' => ['web'],

    /*
    |--------------------------------------------------------------------------
    | Expiration Minutes
    |--------------------------------------------------------------------------
    |
    | Token expiration for mobile apps
    | null = no expiration (tokens last forever until deleted)
    | 60 * 24 * 30 = 30 days
    |
    */

    'expiration' => env('SANCTUM_TOKEN_EXPIRATION', null),

    /*
    |--------------------------------------------------------------------------
    | Token Prefix
    |--------------------------------------------------------------------------
    */

    'token_prefix' => env('SANCTUM_TOKEN_PREFIX', ''),

    /*
    |--------------------------------------------------------------------------
    | Sanctum Middleware
    |--------------------------------------------------------------------------
    |
    | ✅ HYBRID CONFIG: Keep these for SPA support
    | Mobile apps will bypass these and use Bearer tokens
    |
    */

    'middleware' => [
        'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
        'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
        'verify_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
    ],

    /*
    |--------------------------------------------------------------------------
    | Sanctum Route Middleware
    |--------------------------------------------------------------------------
    */

    'route_middleware' => [
        'abilities' => Laravel\Sanctum\Http\Middleware\CheckAbilities::class,
        'ability' => Laravel\Sanctum\Http\Middleware\CheckForAnyAbility::class,
    ],

];