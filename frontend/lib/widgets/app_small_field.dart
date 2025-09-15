import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact form field widgets intended for side-by-side usage (e.g. DoB, Gender)
/// They mirror AppFormField bottom spacing behavior for consistent layout.

class AppSmallTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool? enabled;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final InputDecoration? decoration;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;
  final double bottomSpacing;

  const AppSmallTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.readOnly = false,
    this.enabled,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.autovalidateMode,
    this.decoration,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.bottomSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          enabled: enabled,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autovalidateMode: autovalidateMode,
          decoration: decoration,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
        ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

class AppSmallDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final AutovalidateMode? autovalidateMode;
  final InputDecoration? decoration;
  final double bottomSpacing;
  final Key? dropdownKey;

  const AppSmallDropdown({
    super.key,
    this.initialValue,
    this.items,
    this.onChanged,
    this.validator,
    this.autovalidateMode,
    this.decoration,
    this.bottomSpacing = 0,
    this.dropdownKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<T>(
          key: dropdownKey,
          initialValue: initialValue,
          items: items,
          onChanged: onChanged,
          validator: validator,
          autovalidateMode: autovalidateMode,
          decoration: decoration,
        ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}
