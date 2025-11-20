import 'package:flutter/material.dart';
import '../utils/constants.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppConstants.primaryGold,
              ),
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              message!,
              style: const TextStyle(
                color: AppConstants.textGray,
                fontSize: AppConstants.fontMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class CustomLoadingDialog extends StatelessWidget {
  final String message;

  const CustomLoadingDialog({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppConstants.charcoalGray,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppConstants.primaryGold,
                ),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(width: AppConstants.paddingLarge),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: AppConstants.fontLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
