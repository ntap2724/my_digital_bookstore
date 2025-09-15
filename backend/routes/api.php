<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Models\User;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ChangePasswordController;

// Auth routes
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth:api');

// Change password (requires auth)
Route::post('/change-password', ChangePasswordController::class)->middleware('auth:api');

// Get current user
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:api');

// Update current user profile (requires auth)
Route::put('/user', function (Request $request) {
    $user = $request->user();
    $minDob = now()->subYears(13)->toDateString();
    $data = $request->validate([
        'name' => ['sometimes','required','string','max:255'],
        'phone' => ['sometimes','required','string','regex:/^(0|\+84)(\d{9})$/'],
        'dob' => ['sometimes','required','date','before_or_equal:'.$minDob],
        'gender' => ['sometimes','required','string','in:male,female,other'],
    ]);
    if(isset($data['name'])) $user->name = $data['name'];
    if(isset($data['phone'])) $user->phone = $data['phone'];
    if(isset($data['dob'])) $user->dob = $data['dob'];
    if(isset($data['gender'])) $user->gender = $data['gender'];
    $user->save();
    return $user;
})->middleware('auth:api');

// Check if an email exists in the user database
Route::get('/email-exists', function (Request $request) {
    $email = $request->query('email');
    if (!$email || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return response()->json(['exists' => false], 200);
    }
    $exists = User::where('email', $email)->exists();
    return response()->json(['exists' => $exists]);
});

