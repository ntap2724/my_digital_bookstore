import 'package:flutter/material.dart';

class LinkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool centered;
  final EdgeInsetsGeometry padding;
  final bool inline; // inline text-style link (no extra padding/height)
  final TextStyle? style; // explicit text style to match surrounding text

  const LinkButton(
    this.text, {
    super.key,
    this.onPressed,
    this.centered = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.inline = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final pad = inline ? EdgeInsets.zero : padding;
    final btn = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        padding: pad,
        minimumSize: inline ? const Size(0, 0) : null,
        tapTargetSize: inline
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        alignment: inline ? Alignment.centerLeft : null,
        overlayColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: Text(text, style: style),
    );
    if (!centered) return btn;
    return Align(alignment: Alignment.center, child: btn);
  }
}
