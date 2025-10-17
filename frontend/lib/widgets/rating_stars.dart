import 'package:flutter/material.dart';

/// Widget hiển thị rating dạng ngôi sao (read-only)
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 20,
    this.color,
  });

  final double rating;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? Colors.amber;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;

        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return Icon(icon, size: size, color: starColor);
      }),
    );
  }
}

/// Widget để chọn rating (interactive)
class RatingSelector extends StatelessWidget {
  const RatingSelector({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.size = 32,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;

        return IconButton(
          onPressed: () => onRatingChanged(starValue),
          icon: Icon(
            isFilled ? Icons.star : Icons.star_border,
            size: size,
            color: Colors.amber,
          ),
          padding: const EdgeInsets.all(4),
          constraints: BoxConstraints.tight(Size(size + 8, size + 8)),
        );
      }),
    );
  }
}
