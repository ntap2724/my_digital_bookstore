<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $minDob = now()->subYears(13)->toDateString();

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:'.User::class],
            'password' => [
                'required', 'string', 'min:8', 'confirmed',
                // At least 1 lowercase, 1 uppercase, 1 digit, 1 special char
                'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$/',
            ],
            'phone' => ['required', 'string', 'regex:/^(0|\+84)(\d{9})$/'],
            'dob' => ['required', 'date', 'before_or_equal:'.$minDob],
            'gender' => ['required', 'string', 'in:male,female,other'],
            'accepted_terms' => ['accepted'],
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => $validated['password'],
            'phone' => $validated['phone'],
            'dob' => $validated['dob'],
            'gender' => $validated['gender'],
            'terms_accepted_at' => now(),
        ]);

        $tokenResult = $user->createToken('api');
        $accessToken = $tokenResult->accessToken;

        return response()->json([
            'user' => $user,
            'access_token' => $accessToken,
            'token' => $accessToken,
            'token_type' => 'Bearer',
        ], 201);
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid credentials.'],
            ]);
        }

        $tokenResult = $user->createToken('api');
        $accessToken = $tokenResult->accessToken;

        return response()->json([
            'user' => $user,
            'access_token' => $accessToken,
            'token' => $accessToken,
            'token_type' => 'Bearer',
        ]);
    }

    public function logout(Request $request)
    {
        $token = $request->user()->token();
        if ($token) {
            $token->revoke();
        }

        return response()->json([
            'message' => 'Logged out',
        ]);
    }
}
