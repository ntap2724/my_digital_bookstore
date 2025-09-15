import 'package:flutter/material.dart';

/// Utilities and small widgets to keep form helper texts aligned and spaced
/// consistently with TextFormField content paddings across the app.

// Global spacing constants to keep margins consistent everywhere
const double kFieldSpacing = 16.0; // default gap between fields
const double kHelperTopSpacing = 8.0; // space from field to helper
const double kHelperBottomSpacing = 16.0; // space from helper to next block

/// Returns the left inset used by input content so helper texts can align
/// with the field text (not with the outer border).
double fieldLeftInset(BuildContext context) {
  final theme = Theme.of(context);
  final padding = theme.inputDecorationTheme.contentPadding;
  if (padding == null) return 12.0;
  return padding.resolve(Directionality.of(context)).left;
}

/// Returns the text style used for error/helper lines to keep a consistent
/// size across success/error/info messages.
TextStyle helperTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.inputDecorationTheme.errorStyle ?? const TextStyle(fontSize: 12);
}

/// A helper wrapper that pads the given [child] to align with the left inset
/// of the form field content, and applies a standard top/bottom spacing.
class FieldHelper extends StatelessWidget {
  final Widget child;
  final double top;
  final double bottom;
  final double extraLeft;

  const FieldHelper({
    super.key,
    required this.child,
    this.top = kHelperTopSpacing,
    this.bottom = kHelperBottomSpacing,
    this.extraLeft = 0,
  });

  @override
  Widget build(BuildContext context) {
    final left = fieldLeftInset(context) + extraLeft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: top),
        Padding(
          padding: EdgeInsets.only(left: left),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: child,
          ),
        ),
        SizedBox(height: bottom),
      ],
    );
  }
}

double prefixIconInsetGuess(BuildContext context) {
  final theme = Theme.of(context);
  final c = theme.inputDecorationTheme.prefixIconConstraints;
  return (c?.minWidth ?? 48.0);
}
