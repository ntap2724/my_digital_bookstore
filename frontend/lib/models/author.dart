class Author {
  final int id;
  final String name;
  final String slug;
  final String? avatarUrl;
  final String? bio;

  const Author({
    required this.id,
    required this.name,
    required this.slug,
    this.avatarUrl,
    this.bio,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
    );
  }
}
