import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 56,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: backgroundColor ?? AppConstants.primaryGold,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
              ),
              child: _buildChild(),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? AppConstants.primaryGold,
                foregroundColor: textColor ?? AppConstants.primaryBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                elevation: 0,
              ),
              child: _buildChild(),
            ),
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: AppConstants.fontLarge,
              fontWeight: FontWeight.w600,
              color: isOutlined
                  ? (textColor ?? AppConstants.primaryGold)
                  : (textColor ?? AppConstants.primaryBlack),
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: AppConstants.fontLarge,
        fontWeight: FontWeight.w600,
        color: isOutlined
            ? (textColor ?? AppConstants.primaryGold)
            : (textColor ?? AppConstants.primaryBlack),
      ),
    );
  }
}
