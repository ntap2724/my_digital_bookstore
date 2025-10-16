<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTopUpRequest;
use App\Models\WalletTransaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\Response;

class WalletTopUpRequestController extends Controller
{
    public function index(Request $request): Response
    {
        $user = $request->user();
        if (! $user) {
            abort(401, 'Authentication required');
        }

        $perPage = (int) $request->input('per_page', 20);
        $perPage = max(1, min($perPage, 100));

        $query = WalletTopUpRequest::query()->with(['user:id,name,email']);

        $isAdmin = Gate::forUser($user)->allows('admin');

        if ($isAdmin && $request->filled('user_id')) {
            $query->where('user_id', (int) $request->input('user_id'));
        } elseif (! $isAdmin) {
            $query->where('user_id', $user->id);
        }

        if ($status = $request->string('status')->trim()->toString()) {
            $query->where('status', $status);
        }

        $query->latest('created_at');

        $paginator = $query->paginate($perPage)->appends($request->query());

        return response()->json([
            'data' => $paginator->getCollection()->map(fn (WalletTopUpRequest $topUp) => $this->transform($topUp)),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function store(Request $request): Response
    {
        $user = $request->user();
        if (! $user) {
            abort(401, 'Authentication required');
        }

        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1'],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $topUp = WalletTopUpRequest::create([
            'user_id' => $user->id,
            'amount' => (int) $data['amount'],
            'note' => $data['note'] ?? null,
            'status' => 'pending',
        ]);

        return response()->json([
            'data' => $this->transform($topUp->fresh(['user:id,name,email'])),
        ], 201);
    }

    public function show(Request $request, WalletTopUpRequest $walletTopUp): Response
    {
        $user = $request->user();
        if (! $user) {
            abort(401, 'Authentication required');
        }

        $isAdmin = Gate::forUser($user)->allows('admin');

        if (! $isAdmin && $walletTopUp->user_id !== $user->id) {
            abort(403, 'Forbidden');
        }

        $walletTopUp->loadMissing('user:id,name,email', 'responder:id,name');

        return response()->json([
            'data' => $this->transform($walletTopUp),
        ]);
    }

    public function approve(Request $request, WalletTopUpRequest $walletTopUp): Response
    {
        Gate::authorize('admin');

        if ($walletTopUp->status !== 'pending') {
            return response()->json([
                'message' => 'This request has already been processed.',
            ], 422);
        }

        $data = $request->validate([
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $user = $walletTopUp->user;
        if (! $user) {
            abort(404, 'User not found for this request.');
        }

        DB::transaction(function () use ($walletTopUp, $user, $data): void {
            $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);
            $amount = (int) $walletTopUp->amount;

            $balanceBefore = $wallet->balance;
            $balanceAfter = $balanceBefore + $amount;

            $wallet->update(['balance' => $balanceAfter]);

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'credit',
                'amount' => $amount,
                'balance_before' => $balanceBefore,
                'balance_after' => $balanceAfter,
                'performed_by' => request()->user()?->id,
                'description' => 'Wallet top-up approved',
                'meta' => [
                    'top_up_request_id' => $walletTopUp->id,
                ],
            ]);

            $walletTopUp->status = 'approved';
            $walletTopUp->response_note = $data['note'] ?? null;
            $walletTopUp->responded_by = request()->user()?->id;
            $walletTopUp->responded_at = now();
            $walletTopUp->save();
        });

        $walletTopUp->loadMissing('user:id,name,email', 'responder:id,name');

        return response()->json([
            'data' => $this->transform($walletTopUp),
        ]);
    }

    public function reject(Request $request, WalletTopUpRequest $walletTopUp): Response
    {
        Gate::authorize('admin');

        if ($walletTopUp->status !== 'pending') {
            return response()->json([
                'message' => 'This request has already been processed.',
            ], 422);
        }

        $data = $request->validate([
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $walletTopUp->status = 'rejected';
        $walletTopUp->response_note = $data['note'] ?? null;
        $walletTopUp->responded_by = $request->user()?->id;
        $walletTopUp->responded_at = now();
        $walletTopUp->save();

        $walletTopUp->loadMissing('user:id,name,email', 'responder:id,name');

        return response()->json([
            'data' => $this->transform($walletTopUp),
        ]);
    }

    private function transform(WalletTopUpRequest $topUp): array
    {
        $topUp->loadMissing('user:id,name,email', 'responder:id,name');

        return [
            'id' => $topUp->id,
            'user_id' => $topUp->user_id,
            'amount' => (int) $topUp->amount,
            'status' => $topUp->status,
            'note' => $topUp->note,
            'response_note' => $topUp->response_note,
            'responded_by' => $topUp->responded_by,
            'responded_at' => optional($topUp->responded_at)->toISOString(),
            'created_at' => optional($topUp->created_at)->toISOString(),
            'updated_at' => optional($topUp->updated_at)->toISOString(),
            'user' => $topUp->user?->only(['id', 'name', 'email']),
            'responder' => $topUp->responder?->only(['id', 'name', 'email']),
        ];
    }
}
