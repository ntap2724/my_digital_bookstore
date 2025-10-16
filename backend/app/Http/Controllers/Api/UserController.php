<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('admin');

        $perPage = (int) $request->input('per_page', 20);
        $perPage = max(1, min($perPage, 100));

        $query = User::query()->orderBy('id');

        if ($search = $request->string('search')->trim()->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($role = $request->string('role')->trim()->toString()) {
            $query->where('role', $role);
        }

        $paginator = $query->paginate($perPage)->appends($request->query());

        return response()->json([
            'data' => $paginator->getCollection()->map(fn (User $user) => $this->transform($user))->values(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function store(Request $request)
    {
        Gate::authorize('admin');

        $minDob = now()->subYears(13)->toDateString();

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:'.User::class],
            'password' => [
                'required', 'string', 'min:8',
                'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$/',
            ],
            'role' => ['required', 'string', Rule::in(['admin', 'user'])],
            'phone' => ['nullable', 'string', 'regex:/^(0|\+84)(\d{9})$/'],
            'dob' => ['nullable', 'date', 'before_or_equal:'.$minDob],
            'gender' => ['nullable', 'string', 'in:male,female,other'],
            'accepted_terms' => ['sometimes', 'boolean'],
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => $validated['password'],
            'role' => $validated['role'],
            'phone' => $validated['phone'] ?? null,
            'dob' => $validated['dob'] ?? null,
            'gender' => $validated['gender'] ?? null,
            'terms_accepted_at' => ($validated['accepted_terms'] ?? false) ? now() : null,
        ]);

        return response()->json([
            'data' => $this->transform($user->refresh()),
        ], 201);
    }

    public function show(User $user)
    {
        Gate::authorize('admin');

        return response()->json([
            'data' => $this->transform($user),
        ]);
    }

    public function update(Request $request, User $user)
    {
        Gate::authorize('admin');

        $minDob = now()->subYears(13)->toDateString();

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'email' => ['sometimes', 'required', 'string', 'email', 'max:255', Rule::unique(User::class)->ignore($user->id)],
            'password' => [
                'sometimes', 'required', 'string', 'min:8',
                'regex:/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$/',
            ],
            'role' => ['sometimes', 'required', 'string', Rule::in(['admin', 'user'])],
            'phone' => ['sometimes', 'nullable', 'string', 'regex:/^(0|\+84)(\d{9})$/'],
            'dob' => ['sometimes', 'nullable', 'date', 'before_or_equal:'.$minDob],
            'gender' => ['sometimes', 'nullable', 'string', 'in:male,female,other'],
            'accepted_terms' => ['sometimes', 'boolean'],
        ]);

        if (isset($validated['name'])) {
            $user->name = $validated['name'];
        }

        if (isset($validated['email'])) {
            $user->email = $validated['email'];
        }

        if (isset($validated['password'])) {
            $user->password = $validated['password'];
            $user->tokens()->delete();
        }

        if (isset($validated['role'])) {
            $user->role = $validated['role'];
        }

        if (array_key_exists('phone', $validated)) {
            $user->phone = $validated['phone'];
        }

        if (array_key_exists('dob', $validated)) {
            $user->dob = $validated['dob'];
        }

        if (array_key_exists('gender', $validated)) {
            $user->gender = $validated['gender'];
        }

        if (array_key_exists('accepted_terms', $validated)) {
            $user->terms_accepted_at = $validated['accepted_terms'] ? now() : null;
        }

        $user->save();

        return response()->json([
            'data' => $this->transform($user->refresh()),
        ]);
    }

    public function destroy(Request $request, User $user)
    {
        Gate::authorize('admin');

        if ($request->user()->is($user)) {
            return response()->json([
                'message' => 'You cannot delete your own account.',
            ], 422);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json([
            'message' => 'User deleted',
        ]);
    }

    private function transform(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'phone' => $user->phone,
            'dob' => optional($user->dob)->toDateString(),
            'gender' => $user->gender,
            'terms_accepted_at' => optional($user->terms_accepted_at)->toISOString(),
            'created_at' => optional($user->created_at)->toISOString(),
            'updated_at' => optional($user->updated_at)->toISOString(),
        ];
    }
}
