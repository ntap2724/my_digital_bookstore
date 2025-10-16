<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class CategoryController extends Controller
{
    public function index(Request $request)
    {
        $query = Category::query()->orderBy('name');

        if ($search = $request->string('search')->trim()->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        $categories = $query->get();

        return response()->json([
            'data' => $categories->map(fn (Category $category) => $this->transform($category)),
        ]);
    }

    public function show(Category $category)
    {
        return response()->json([
            'data' => $this->transform($category),
        ]);
    }

    public function store(Request $request)
    {
        Gate::authorize('admin');

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', 'unique:categories,slug'],
            'description' => ['nullable', 'string'],
        ]);

        $category = Category::create($validated);

        return response()->json([
            'data' => $this->transform($category->refresh()),
        ], 201);
    }

    public function update(Request $request, Category $category)
    {
        Gate::authorize('admin');

        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'slug' => ['nullable', 'string', 'max:255', Rule::unique('categories')->ignore($category->id)],
            'description' => ['nullable', 'string'],
        ]);

        $category->fill($validated)->save();

        return response()->json([
            'data' => $this->transform($category->refresh()),
        ]);
    }

    public function destroy(Category $category)
    {
        Gate::authorize('admin');

        if ($category->books()->exists()) {
            return response()->json([
                'message' => 'Cannot delete category with associated books.',
            ], 422);
        }

        $category->delete();

        return response()->json([
            'message' => 'Category deleted',
        ]);
    }

    private function transform(Category $category): array
    {
        return [
            'id' => $category->id,
            'name' => $category->name,
            'slug' => $category->slug,
            'description' => $category->description,
        ];
    }
}
