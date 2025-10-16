<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class WalletController extends Controller
{
    private function jsonResponse(array $data, int $status = 200): Response
    {
        return response()->json($data, $status, [], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    }


    public function current(Request $request)
    {
        $user = $request->user();
        if (! $user) {
            abort(401, 'Authentication required');
        }

        $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);
        $wallet->load(['transactions' => fn ($q) => $q->latest()->limit(10)]);

        return $this->jsonResponse([
            'data' => $this->transformWallet($wallet, includeTransactions: true),
        ]);
    }

    public function currentTransactions(Request $request)
    {
        $user = $request->user();
        if (! $user) {
            abort(401, 'Authentication required');
        }

        $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);

        $perPage = (int) $request->input('per_page', 20);
        $perPage = max(1, min($perPage, 100));

        $paginator = $wallet->transactions()->latest()->paginate($perPage)->appends($request->query());

        return $this->jsonResponse([
            'data' => $paginator->getCollection()->map(fn (WalletTransaction $tx) => $this->transformTransaction($tx)),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function index(Request $request)
    {
        Gate::authorize('admin');

        $perPage = (int) $request->input('per_page', 20);
        $perPage = max(1, min($perPage, 100));

        $paginator = Wallet::query()
            ->with('user')
            ->orderBy('updated_at', 'desc')
            ->paginate($perPage)
            ->appends($request->query());

        return $this->jsonResponse([
            'data' => $paginator->getCollection()->map(fn (Wallet $wallet) => $this->transformWallet($wallet)),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function showForUser(User $user)
    {
        Gate::authorize('admin');

        $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);
        $wallet->load('user', 'transactions');

        return $this->jsonResponse([
            'data' => $this->transformWallet($wallet, includeTransactions: true),
        ]);
    }

    public function transactionsForUser(Request $request, User $user)
    {
        Gate::authorize('admin');

        $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);

        $perPage = (int) $request->input('per_page', 20);
        $perPage = max(1, min($perPage, 100));

        $paginator = $wallet->transactions()->latest()->paginate($perPage)->appends($request->query());

        return $this->jsonResponse([
            'data' => $paginator->getCollection()->map(fn (WalletTransaction $tx) => $this->transformTransaction($tx)),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function adjust(Request $request, User $user)
    {
        Gate::authorize('admin');

        $validated = $request->validate([
            'type' => ['required', 'string', Rule::in(['credit', 'debit', 'adjustment'])],
            'amount' => ['required', 'integer', 'min:0'],
            'description' => ['nullable', 'string'],
            'reference' => ['nullable', 'string', 'max:255'],
            'meta' => ['nullable', 'array'],
        ]);

        $amount = (int) $validated['amount'];
        $type = $validated['type'];

        if (in_array($type, ['credit', 'debit'], true) && $amount < 1) {
            return $this->jsonResponse([
                'message' => 'Amount must be at least 1 for credit or debit adjustments.',
            ], 422);
        }

        $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);

        if ($type === 'adjustment') {
            $desired = $amount;
            $transaction = null;

            DB::transaction(function () use (&$transaction, $wallet, $validated, $desired): void {
                $balanceBefore = $wallet->balance;
                $balanceAfter = $desired;

                $wallet->update(['balance' => $balanceAfter]);

                $meta = $validated['meta'] ?? [];
                if (! is_array($meta)) {
                    $meta = [];
                }
                $meta['desired_balance'] = $desired;

                $transaction = WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'type' => 'adjustment',
                    'amount' => abs($balanceAfter - $balanceBefore),
                    'balance_before' => $balanceBefore,
                    'balance_after' => $balanceAfter,
                    'performed_by' => auth()->id(),
                    'reference' => $validated['reference'] ?? null,
                    'description' => $validated['description'] ?? 'Manual balance adjustment',
                    'meta' => $meta,
                ]);
            });

            return $this->jsonResponse([
                'data' => $this->transformTransaction($transaction?->fresh()),
            ], 201);
        }

        if ($type === 'debit' && $wallet->balance < $amount) {
            return $this->jsonResponse([
                'message' => 'Wallet balance is insufficient for this debit.',
            ], 422);
        }

        $transaction = null;

        DB::transaction(function () use (&$transaction, $wallet, $validated, $amount, $type): void {
            $balanceBefore = $wallet->balance;
            $balanceAfter = $type === 'credit'
                ? $balanceBefore + $amount
                : $balanceBefore - $amount;

            $wallet->update(['balance' => $balanceAfter]);

            $transaction = WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => $type,
                'amount' => $amount,
                'balance_before' => $balanceBefore,
                'balance_after' => $balanceAfter,
                'performed_by' => auth()->id(),
                'reference' => $validated['reference'] ?? null,
                'description' => $validated['description'] ?? ($type === 'credit' ? 'Manual credit adjustment' : 'Manual debit adjustment'),
                'meta' => $validated['meta'] ?? null,
            ]);
        });

        return $this->jsonResponse([
            'data' => $this->transformTransaction($transaction?->fresh()),
        ], 201);
    }

    private function transformWallet(Wallet $wallet, bool $includeTransactions = false): array
    {
        $wallet->loadMissing('user');

        return [
            'id' => $wallet->id,
            'user_id' => $wallet->user_id,
            'balance' => (int) $wallet->balance,
            'updated_at' => optional($wallet->updated_at)->toISOString(),
            'user' => $wallet->user?->only(['id', 'name', 'email']),
            'transactions' => $includeTransactions
                ? $wallet->transactions->map(fn (WalletTransaction $tx) => $this->transformTransaction($tx))->values()
                : null,
        ];
    }

    private function transformTransaction(?WalletTransaction $transaction): array
    {
        if (! $transaction) {
            return [];
        }

        $transaction->loadMissing(['performedBy', 'order']);

        return [
            'id' => $transaction->id,
            'type' => $transaction->type,
            'amount' => (int) $transaction->amount,
            'balance_before' => (int) $transaction->balance_before,
            'balance_after' => (int) $transaction->balance_after,
            'order_id' => $transaction->order_id,
            'performed_by' => $transaction->performed_by,
            'reference' => $transaction->reference,
            'description' => $transaction->description,
            'meta' => $transaction->meta,
            'created_at' => optional($transaction->created_at)->toISOString(),
        ];
    }
}
