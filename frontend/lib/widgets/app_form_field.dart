import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/widgets/form_utils.dart';

/// AppFormField wraps a TextFormField and adds a consistent bottom margin
/// to keep forms visually balanced across the app.
class AppFormField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool? enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final int? maxLines;
  final double bottomSpacing;

  const AppFormField({
    super.key,
    this.controller,
    this.focusNode,
    this.enabled,
    this.readOnly = false,
    this.obscureText = false,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.autovalidateMode,
    this.decoration,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.maxLines = 1,
    this.bottomSpacing = kFieldSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autovalidateMode: autovalidateMode,
          decoration: decoration,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
          maxLines: obscureText ? 1 : maxLines,
        ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}
