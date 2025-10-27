import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/gradient_card.dart';

/// A hero section with branding for login/register pages
class BookStoreHero extends StatelessWidget {
  const BookStoreHero({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 48,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GradientCard(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 20 : 32,
        horizontal: compact ? 16 : 24,
      ),
      margin: EdgeInsets.only(bottom: compact ? 16 : 24),
      elevation: 2,
      child: Column(
        children: [
          // Icon with background circle
          Container(
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surface.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 20 : null,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          // Subtitle
          if (subtitle != null) ...[
            SizedBox(height: compact ? 6 : 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: compact ? 13 : null,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
