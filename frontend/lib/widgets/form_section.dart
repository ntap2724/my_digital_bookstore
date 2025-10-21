import 'package:flutter/material.dart';

/// A section wrapper for grouping related form fields with optional header
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    required this.children,
    this.spacing = 12,
    this.showCard = false,
    this.cardPadding = const EdgeInsets.all(16),
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final double spacing;
  final bool showCard;
  final EdgeInsetsGeometry cardPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || icon != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
        ],
        ...List.generate(
          children.length,
          (i) => Column(
            children: [
              children[i],
              if (i < children.length - 1) SizedBox(height: spacing),
            ],
          ),
        ),
      ],
    );

    if (showCard) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: cardPadding,
          child: content,
        ),
      );
    }

    return content;
  }
}
