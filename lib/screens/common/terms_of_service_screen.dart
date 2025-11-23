import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terms of Service'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GenZFit Terms of Service',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last Updated: November 2025',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              'Acceptance of Terms',
              'By accessing and using GenZFit, you accept and agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our app.',
            ),

            _buildSection(
              'Description of Service',
              'GenZFit provides:\n\n'
              '• AI-powered body scanning and measurement tracking\n'
              '• Personalized fitness and nutrition recommendations\n'
              '• Access to certified fitness trainers\n'
              '• Workout and meal planning tools\n'
              '• Progress tracking and analytics\n'
              '• AI chatbot for fitness guidance',
            ),

            _buildSection(
              'User Accounts',
              'Account Creation:\n'
              '• You must be at least 13 years old to use GenZFit\n'
              '• You must provide accurate and complete information\n'
              '• You are responsible for maintaining account security\n'
              '• You must not share your account credentials\n\n'
              'Account Termination:\n'
              '• We reserve the right to suspend or terminate accounts for violations\n'
              '• You may delete your account at any time through the app',
            ),

            _buildSection(
              'User Responsibilities',
              'You agree to:\n\n'
              '• Provide accurate body measurements and health information\n'
              '• Use the app for lawful purposes only\n'
              '• Not misuse or abuse the service\n'
              '• Not attempt to hack or compromise our systems\n'
              '• Respect the privacy of other users\n'
              '• Not upload inappropriate or offensive content\n'
              '• Follow trainer guidelines and recommendations responsibly',
            ),

            _buildSection(
              'Health and Safety Disclaimer',
              'IMPORTANT:\n\n'
              '• GenZFit is not a medical service or healthcare provider\n'
              '• Our recommendations are for general fitness purposes only\n'
              '• Always consult a healthcare professional before starting any fitness program\n'
              '• Body measurements are estimates and may not be 100% accurate\n'
              '• We are not liable for any injuries or health issues\n'
              '• Stop exercising and seek medical help if you experience pain or discomfort',
            ),

            _buildSection(
              'Trainer Services',
              'Regarding trainer interactions:\n\n'
              '• Trainers are independent professionals\n'
              '• GenZFit facilitates connections but does not employ trainers\n'
              '• Verify trainer credentials before engaging services\n'
              '• Payment disputes should be resolved between you and the trainer\n'
              '• Report any misconduct to GenZFit support immediately',
            ),

            _buildSection(
              'Content and Intellectual Property',
              'Your Content:\n'
              '• You retain ownership of your body scan photos and data\n'
              '• You grant us license to use your data to provide services\n'
              '• You may delete your content at any time\n\n'
              'Our Content:\n'
              '• GenZFit and its logo are trademarks\n'
              '• All app content, design, and features are protected\n'
              '• You may not copy, modify, or distribute our content without permission',
            ),

            _buildSection(
              'Payment and Subscriptions',
              'For premium features:\n\n'
              '• Prices are displayed in the app\n'
              '• Subscriptions auto-renew unless cancelled\n'
              '• Refunds are subject to our refund policy\n'
              '• We reserve the right to change pricing with notice\n'
              '• Promotional offers may have specific terms',
            ),

            _buildSection(
              'Privacy',
              'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information.',
            ),

            _buildSection(
              'Limitation of Liability',
              'To the maximum extent permitted by law:\n\n'
              '• GenZFit is provided "as is" without warranties\n'
              '• We are not liable for any indirect, incidental, or consequential damages\n'
              '• Our total liability is limited to the amount you paid us\n'
              '• We do not guarantee specific fitness results\n'
              '• We are not responsible for third-party content or services',
            ),

            _buildSection(
              'Modifications to Service',
              'We reserve the right to:\n\n'
              '• Modify or discontinue features at any time\n'
              '• Update these terms with notice to users\n'
              '• Change pricing for new subscriptions\n'
              '• Improve and update the app regularly',
            ),

            _buildSection(
              'Governing Law',
              'These terms are governed by the laws of [Your Jurisdiction]. Any disputes will be resolved in the courts of [Your Jurisdiction].',
            ),

            _buildSection(
              'Contact Information',
              'For questions about these Terms:\n\n'
              'Email: legal@genzfit.com\n'
              'Support: support@genzfit.com\n'
              'Website: www.genzfit.com',
            ),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using GenZFit, you acknowledge that you have read, understood, and agree to these Terms of Service.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
