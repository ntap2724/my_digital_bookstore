<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Book;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Models\UserBook;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpKernel\Exception\HttpException;

class OrderController extends Controller
{
    public function index(Request $request)
    {
        $perPage = (int) $request->input('per_page', 10);
        $perPage = max(1, min($perPage, 100));

        $query = Order::query()->with(['items.book.authors', 'user'])->latest('placed_at')->latest('id');

        $user = $request->user();
        $isAdmin = $user && Gate::forUser($user)->allows('admin');

        if (! $isAdmin) {
            $query->where('user_id', $user?->id ?: 0);
        } elseif ($userId = $request->integer('user_id')) {
            $query->where('user_id', $userId);
        }

        if ($status = $request->string('status')->trim()->toString()) {
            $query->where('status', $status);
        }

        $paginator = $query->paginate($perPage)->appends($request->query());

        return response()->json([
            'data' => $paginator->getCollection()->map(fn (Order $order) => $this->transform($order)),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    public function show(Request $request, Order $order)
    {
        $this->authorizeView($request, $order);

        $order->load(['items.book.authors', 'user']);

        return response()->json([
            'data' => $this->transform($order),
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        if (! $user) {
            throw new HttpException(401, 'Authentication required');
        }

        $payload = $request->validate([
            'items' => ['required', 'array', 'min:1'],
            'items.*.book_id' => ['required', 'integer', 'exists:books,id'],
            'items.*.quantity' => ['nullable', 'integer', 'min:1'],
            'note' => ['nullable', 'string'],
        ]);

        $items = collect($payload['items'])
            ->map(function (array $item): array {
                return [
                    'book_id' => (int) $item['book_id'],
                    'quantity' => 1,
                ];
            });

        $bookIds = $items->pluck('book_id')->unique();
        $books = Book::query()->whereIn('id', $bookIds)->get()->keyBy('id');

        if ($books->count() !== $bookIds->count()) {
            return response()->json([
                'message' => 'Some books could not be found.',
            ], 422);
        }

        $total = 0;
        $itemPayloads = [];
        foreach ($items as $item) {
            $book = $books[$item['book_id']];
            $quantity = $item['quantity'];
            $lineTotal = (int) $book->credit_price * $quantity;
            $total += $lineTotal;

            $itemPayloads[] = [
                'book' => $book,
                'quantity' => $quantity,
                'unit_credit' => (int) $book->credit_price,
                'total_credit' => $lineTotal,
            ];
        }

        if ($total <= 0) {
            return response()->json([
                'message' => 'Order total must be greater than zero.',
            ], 422);
        }

        $wallet = Wallet::firstOrCreate(['user_id' => $user->id], ['balance' => 0]);

        if ($wallet->balance < $total) {
            return response()->json([
                'message' => 'Ví của bạn không đủ credit để thanh toán đơn hàng.',
            ], 422);
        }

        $order = null;

        $existingUserBooks = UserBook::query()
            ->where('user_id', $user->id)
            ->whereIn('book_id', $bookIds)
            ->pluck('book_id')
            ->map(fn ($id) => (int) $id)
            ->all();

        if (! empty($existingUserBooks)) {
            $titles = $books->only($existingUserBooks)->pluck('title')->filter()->values();

            return response()->json([
                'message' => 'You already own some of these books.',
                'books' => $titles,
            ], 422);
        }

        $outOfStock = $books->filter(fn (Book $book) => (int) $book->available_copies <= 0)->values();

        if ($outOfStock->isNotEmpty()) {
            return response()->json([
                'message' => 'Some books are out of stock.',
                'books' => $outOfStock->pluck('title')->filter()->values(),
            ], 422);
        }

        DB::transaction(function () use (&$order, $user, $payload, $itemPayloads, $total, $wallet): void {
            $timestamp = now();

            $lockedBooks = [];
            foreach ($itemPayloads as $item) {
                $locked = Book::query()
                    ->whereKey($item['book']->id)
                    ->lockForUpdate()
                    ->first();

                if (! $locked || (int) $locked->available_copies <= 0) {
                    throw new HttpException(422, 'Some books are out of stock.');
                }

                $lockedBooks[$locked->id] = $locked;
            }

            $order = Order::create([
                'user_id' => $user->id,
                'total_credit' => $total,
                'status' => 'completed',
                'note' => $payload['note'] ?? null,
                'placed_at' => $timestamp,
                'completed_at' => $timestamp,
            ]);

            foreach ($itemPayloads as $item) {
                OrderItem::create([
                    'order_id' => $order->id,
                    'book_id' => $item['book']->id,
                    'quantity' => $item['quantity'],
                    'unit_credit' => $item['unit_credit'],
                    'total_credit' => $item['total_credit'],
                ]);
            }

            foreach ($itemPayloads as $item) {
                $book = $item['book'];
                $lockedBook = $lockedBooks[$book->id] ?? null;

                if ($lockedBook) {
                    $lockedBook->available_copies = max(0, (int) $lockedBook->available_copies - 1);
                    $lockedBook->save();

                    $book->available_copies = $lockedBook->available_copies;
                }

                UserBook::create([
                    'user_id' => $user->id,
                    'book_id' => $book->id,
                    'order_id' => $order->id,
                    'first_purchased_at' => $timestamp,
                    'last_purchased_at' => $timestamp,
                ]);
            }

            $balanceBefore = $wallet->balance;
            $balanceAfter = $balanceBefore - $total;
            $wallet->update(['balance' => $balanceAfter]);

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'debit',
                'amount' => $total,
                'balance_before' => $balanceBefore,
                'balance_after' => $balanceAfter,
                'order_id' => $order->id,
                'performed_by' => $user->id,
                'description' => 'Thanh toán đơn hàng',
                'meta' => ['items' => collect($itemPayloads)->map(fn ($i) => $i['book']->title)],
            ]);
        });

        $order?->load(['items.book.authors', 'user']);

        return response()->json([
            'data' => $this->transform($order),
        ], 201);
    }

    public function cancel(Request $request, Order $order)
    {
        $user = $request->user();
        $isAdmin = $user && Gate::forUser($user)->allows('admin');

        if (! $isAdmin && $order->user_id !== $user?->id) {
            abort(403, 'Bạn không thể hủy đơn hàng này.');
        }

        if ($order->status === 'cancelled') {
            return response()->json([
                'message' => 'Đơn hàng đã được hủy trước đó.',
            ], 422);
        }

        DB::transaction(function () use ($request, $order, $isAdmin, $user): void {
            $order->status = 'cancelled';
            $order->cancelled_at = now();
            $order->completed_at = null;
            $order->save();

            $wallet = Wallet::firstOrCreate(['user_id' => $order->user_id], ['balance' => 0]);
            $balanceBefore = $wallet->balance;
            $wallet->balance = $balanceBefore + $order->total_credit;
            $wallet->save();

            WalletTransaction::create([
                'wallet_id' => $wallet->id,
                'type' => 'credit',
                'amount' => $order->total_credit,
                'balance_before' => $balanceBefore,
                'balance_after' => $wallet->balance,
                'order_id' => $order->id,
                'performed_by' => $isAdmin ? $user?->id : $order->user_id,
                'description' => 'Hoàn tiền do hủy đơn hàng',
                'meta' => Arr::whereNotNull([
                    'reason' => $request->input('reason'),
                ]),
            ]);

            $order->loadMissing('items');

            foreach ($order->items as $item) {
                $userBook = UserBook::query()
                    ->where('user_id', $order->user_id)
                    ->where('book_id', $item->book_id)
                    ->lockForUpdate()
                    ->first();

                $book = Book::query()
                    ->whereKey($item->book_id)
                    ->lockForUpdate()
                    ->first();

                if (! $userBook) {
                    if ($book) {
                        $book->available_copies = ((int) $book->available_copies) + 1;
                        $book->save();
                    }
                    continue;
                }

                if ($userBook->order_id === $order->id) {
                    $userBook->delete();
                }

                if ($book) {
                    $book->available_copies = ((int) $book->available_copies) + 1;
                    $book->save();
                }
            }
        });

        $order->load(['items.book.authors', 'user']);

        return response()->json([
            'data' => $this->transform($order),
        ]);
    }

    private function authorizeView(Request $request, Order $order): void
    {
        $user = $request->user();
        $isAdmin = $user && Gate::forUser($user)->allows('admin');

        if (! $isAdmin && $order->user_id !== $user?->id) {
            abort(403, 'Bạn không thể xem đơn hàng này.');
        }
    }

    private function transform(?Order $order): array
    {
        if (! $order) {
            return [];
        }

        $order->loadMissing(['items.book.authors', 'user']);

        return [
            'id' => $order->id,
            'user_id' => $order->user_id,
            'total_credit' => (int) $order->total_credit,
            'status' => $order->status,
            'note' => $order->note,
            'placed_at' => optional($order->placed_at)->toISOString(),
            'completed_at' => optional($order->completed_at)->toISOString(),
            'cancelled_at' => optional($order->cancelled_at)->toISOString(),
            'created_at' => optional($order->created_at)->toISOString(),
            'updated_at' => optional($order->updated_at)->toISOString(),
            'user' => $order->user?->only(['id', 'name', 'email']),
            'items' => $order->items->map(function (OrderItem $item) {
                $book = $item->book;

                return [
                    'id' => $item->id,
                    'book_id' => $item->book_id,
                    'quantity' => (int) $item->quantity,
                    'unit_credit' => (int) $item->unit_credit,
                    'total_credit' => (int) $item->total_credit,
                    'book' => $book ? [
                        'id' => $book->id,
                        'title' => $book->title,
                        'slug' => $book->slug,
                        'credit_price' => (int) $book->credit_price,
                        'authors' => $book->authors->map(fn ($author) => $author->only(['id', 'name']))->values(),
                    ] : null,
                ];
            })->values(),
        ];
    }
}
