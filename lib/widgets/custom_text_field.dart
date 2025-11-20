import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final int maxLines;
  final bool enabled;
  final VoidCallback? onTap;
  final bool readOnly;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.maxLines = 1,
    this.enabled = true,
    this.onTap,
    this.readOnly = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: AppConstants.textWhite,
            fontSize: AppConstants.fontMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          onTap: widget.onTap,
          readOnly: widget.readOnly,
          style: const TextStyle(
            color: AppConstants.textWhite,
            fontSize: AppConstants.fontLarge,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: AppConstants.textDarkGray,
              fontSize: AppConstants.fontLarge,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: AppConstants.textGray,
                  )
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppConstants.textGray,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : widget.suffixIcon != null
                    ? IconButton(
                        icon: Icon(
                          widget.suffixIcon,
                          color: AppConstants.textGray,
                        ),
                        onPressed: widget.onSuffixIconTap,
                      )
                    : null,
            filled: true,
            fillColor: AppConstants.charcoalGray,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: const BorderSide(
                color: AppConstants.slateGray,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: const BorderSide(
                color: AppConstants.primaryGold,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: const BorderSide(
                color: AppConstants.errorRed,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              borderSide: const BorderSide(
                color: AppConstants.errorRed,
                width: 2,
              ),
            ),
            errorStyle: const TextStyle(
              color: AppConstants.errorRed,
              fontSize: AppConstants.fontSmall,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: AppConstants.paddingMedium,
            ),
          ),
        ),
      ],
    );
  }
}
