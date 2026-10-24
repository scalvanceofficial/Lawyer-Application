import 'package:flutter/material.dart';

import 'app_select_field.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.controller,
    this.onChanged,
    this.validator,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
    this.autofillHints,
    this.onFieldSubmitted,
  });

  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      textInputAction: textInputAction,
      readOnly: readOnly,
      onTap: onTap,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(hintText: hint),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Required';
            }
            return null;
          },
    );
  }
}

class AppDropdownField extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.subHint,
  });

  final String hint;
  final String? subHint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>(
      label: hint,
      hint: subHint ?? hint,
      value: value,
      options: options,
      itemLabel: (option) => option,
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }
}
