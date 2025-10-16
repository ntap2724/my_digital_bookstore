class Category {
  final int id;
  final String name;
  final String slug;
  final String? description;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
