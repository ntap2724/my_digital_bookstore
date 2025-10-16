<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Author;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class AuthorController extends Controller
{
    public function index(Request $request)
    {
        $query = Author::query()->orderBy('name');

        if ($search = $request->string('search')->trim()->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        $authors = $query->get();

        return response()->json([
            'data' => $authors->map(fn (Author $author) => $this->transform($author)),
        ]);
    }

    public function show(Author $author)
    {
        return response()->json([
            'data' => $this->transform($author),
        ]);
    }

    public function store(Request $request)
    {
        Gate::authorize('admin');

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', 'unique:authors,slug'],
            'bio' => ['nullable', 'string'],
        ]);

        $author = Author::create($validated);

        return response()->json([
            'data' => $this->transform($author->refresh()),
        ], 201);
    }

    public function update(Request $request, Author $author)
    {
        Gate::authorize('admin');

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', Rule::unique('authors')->ignore($author->id)],
            'bio' => ['nullable', 'string'],
        ]);

        $author->fill($validated)->save();

        return response()->json([
            'data' => $this->transform($author->refresh()),
        ]);
    }

    public function destroy(Author $author)
    {
        Gate::authorize('admin');

        if ($author->books()->exists()) {
            return response()->json([
                'message' => 'Cannot delete author with associated books.',
            ], 422);
        }

        $author->delete();

        return response()->json([
            'message' => 'Author deleted',
        ]);
    }

    private function transform(Author $author): array
    {
        return [
            'id' => $author->id,
            'name' => $author->name,
            'slug' => $author->slug,
            'bio' => $author->bio,
        ];
    }
}
