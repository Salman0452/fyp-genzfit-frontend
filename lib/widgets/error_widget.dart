import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppConstants.errorRed,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              message,
              style: const TextStyle(
                color: AppConstants.textWhite,
                fontSize: AppConstants.fontLarge,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppConstants.paddingLarge),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryGold,
                  foregroundColor: AppConstants.primaryBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLarge,
                    vertical: AppConstants.paddingMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppConstants.textDarkGray,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              message,
              style: const TextStyle(
                color: AppConstants.textGray,
                fontSize: AppConstants.fontLarge,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppConstants.paddingLarge),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
