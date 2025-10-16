import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/form_utils.dart';

class SecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final Widget? label;
  final bool fullWidth;
  final EdgeInsetsGeometry padding;
  final double bottomSpacing;

  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.bottomSpacing = kFieldSpacing,
  }) : icon = null,
       label = null;

  const SecondaryButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.bottomSpacing = kFieldSpacing,
  }) : child = null;

  ButtonStyle _style(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.styleFrom(
      foregroundColor: scheme.primary,
      side: BorderSide(color: scheme.outlineVariant, width: 1.2),
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = (icon != null && label != null)
        ? OutlinedButton.icon(
            style: _style(context),
            onPressed: onPressed,
            icon: icon!,
            label: label!,
          )
        : OutlinedButton(
            style: _style(context),
            onPressed: onPressed,
            child: child ?? const SizedBox.shrink(),
          );
    final core = fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        core,
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}
