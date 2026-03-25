import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/language_provider.dart';
import 'package:genzfit/utils/constants.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Select Language'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
      ),
      body: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Choose your preferred language',
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(
                context,
                languageProvider,
                'en',
                'English',
                'English',
                Icons.language,
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                context,
                languageProvider,
                'ur',
                'اردو',
                'Urdu',
                Icons.language,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1A1A)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen.withOpacity(0.3)
                          : AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The app will restart to apply the language change.',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB0B0B0)
                              : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider languageProvider,
    String languageCode,
    String nativeName,
    String englishName,
    IconData icon,
  ) {
    final isSelected = languageProvider.locale.languageCode == languageCode;

    return GestureDetector(
      onTap: () async {
        await languageProvider.setLanguage(languageCode);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageCode == 'en'
                    ? 'Language changed to English'
                    : 'زبان اردو میں تبدیل ہو گئی',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen.withOpacity(0.1)
                  : AppColors.accent.withOpacity(0.1))
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : AppColors.surface),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          border: Border.all(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1A1A)
                    : AppColors.surface),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2A2A2A)
                        : AppColors.charcoal),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF000000)
                        : const Color(0xFFFFFFFF))
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    englishName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep,
                  size: 28),
          ],
        ),
      ),
    );
  }
}
