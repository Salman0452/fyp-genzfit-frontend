import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GenZFit Privacy Policy',
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
              'Introduction',
              'Welcome to GenZFit. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you about how we look after your personal data when you use our app and tell you about your privacy rights.',
            ),

            _buildSection(
              'Information We Collect',
              'We collect the following types of information:\n\n'
              '• Personal Information: Name, email address, age, gender\n'
              '• Body Measurements: Height, weight, body scan photos, and estimated measurements\n'
              '• Usage Data: How you interact with our app\n'
              '• Device Information: Device type, operating system, unique device identifiers\n'
              '• Location Data: With your permission, for personalized recommendations',
            ),

            _buildSection(
              'How We Use Your Information',
              'We use your information to:\n\n'
              '• Provide and improve our fitness services\n'
              '• Generate personalized workout and nutrition recommendations\n'
              '• Process your body scans and measurements\n'
              '• Connect you with fitness trainers\n'
              '• Send you important updates and notifications\n'
              '• Analyze usage patterns to improve our app\n'
              '• Ensure the security of our services',
            ),

            _buildSection(
              'Data Storage and Security',
              'We implement appropriate security measures to protect your personal information:\n\n'
              '• All data is encrypted in transit and at rest\n'
              '• Body scan photos are securely stored in cloud storage\n'
              '• We use Firebase Authentication for secure login\n'
              '• Regular security audits and updates\n'
              '• Limited access to personal data by authorized personnel only',
            ),

            _buildSection(
              'Sharing Your Information',
              'We do not sell your personal data. We may share your information with:\n\n'
              '• Fitness trainers you choose to work with\n'
              '• Service providers who help us operate the app\n'
              '• Legal authorities when required by law\n\n'
              'Your body measurements and photos are never shared without your explicit consent.',
            ),

            _buildSection(
              'Your Rights',
              'You have the right to:\n\n'
              '• Access your personal data\n'
              '• Correct inaccurate data\n'
              '• Request deletion of your data\n'
              '• Export your data\n'
              '• Withdraw consent at any time\n'
              '• Object to data processing\n\n'
              'To exercise these rights, contact us through the app or email support@genzfit.com',
            ),

            _buildSection(
              'Data Retention',
              'We retain your personal data only as long as necessary for the purposes outlined in this policy. Body scan data is kept for your fitness tracking purposes and can be deleted at any time through the app.',
            ),

            _buildSection(
              'Children\'s Privacy',
              'GenZFit is not intended for users under 13 years of age. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us immediately.',
            ),

            _buildSection(
              'Third-Party Services',
              'Our app uses third-party services:\n\n'
              '• Google ML Kit for pose detection\n'
              '• Cloudinary for image storage\n'
              '• Firebase for authentication and data storage\n'
              '• Google Gemini AI for recommendations\n\n'
              'These services have their own privacy policies governing their use of your information.',
            ),

            _buildSection(
              'Changes to This Policy',
              'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy in the app and updating the "Last Updated" date.',
            ),

            _buildSection(
              'Contact Us',
              'If you have any questions about this privacy policy, please contact us:\n\n'
              'Email: support@genzfit.com\n'
              'Website: www.genzfit.com\n\n'
              'We aim to respond to all inquiries within 48 hours.',
            ),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By using GenZFit, you agree to this Privacy Policy.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
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
