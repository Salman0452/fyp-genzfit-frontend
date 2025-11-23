import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@genzfit.com',
      query: 'subject=GenZFit Support Request',
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Support Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.2),
                    AppColors.accent.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 48,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Our support team is here to help you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _launchEmail,
                    icon: const Icon(Icons.email),
                    label: const Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildFAQItem(
              'How accurate are body measurements?',
              'Our AI-powered measurement system provides estimates with ±2-4cm accuracy, which is sufficient for fitness tracking and 3D avatar generation. For best results, ensure good lighting and follow the on-screen guidelines.',
            ),

            _buildFAQItem(
              'How do I take a body scan?',
              '1. Go to your profile\n'
              '2. Tap "Take Body Scan"\n'
              '3. Stand in good lighting with arms slightly away from body\n'
              '4. Follow the on-screen pose guidelines\n'
              '5. Capture the photo\n'
              '6. Enter your height, weight, age, and gender\n'
              '7. Review AI-predicted measurements and save',
            ),

            _buildFAQItem(
              'Can I edit my measurements?',
              'Currently, measurements cannot be manually edited after prediction. However, you can delete a scan record and take a new one. We recommend this approach to maintain accurate tracking history.',
            ),

            _buildFAQItem(
              'How do I delete a body scan?',
              '1. Go to your profile\n'
              '2. Tap on the scan you want to delete\n'
              '3. Tap the delete icon in the top right or bottom of the screen\n'
              '4. Confirm deletion\n\n'
              'Note: This will permanently delete the scan and all associated photos.',
            ),

            _buildFAQItem(
              'How do I change my password?',
              '1. Go to Settings\n'
              '2. Tap "Change Password"\n'
              '3. Enter your email\n'
              '4. Check your email for a password reset link\n'
              '5. Follow the link to create a new password',
            ),

            _buildFAQItem(
              'How do I update my profile?',
              '1. Go to Settings\n'
              '2. Tap "Edit Profile"\n'
              '3. Update your name, avatar, or fitness goal\n'
              '4. Tap "Update Profile" to save\n\n'
              'Note: Email cannot be changed for security reasons.',
            ),

            _buildFAQItem(
              'What are the fitness goals?',
              'GenZFit supports various goals:\n'
              '• Lose Weight\n'
              '• Build Muscle\n'
              '• Get Fit\n'
              '• Improve Health\n'
              '• Increase Strength\n'
              '• Improve Flexibility\n\n'
              'Your selected goal helps personalize AI recommendations.',
            ),

            _buildFAQItem(
              'How does the AI coach work?',
              'Our AI coach uses Google Gemini to provide personalized fitness and nutrition advice based on your goals, measurements, and progress. It can answer questions, suggest workouts, and help with meal planning.',
            ),

            _buildFAQItem(
              'Can I use GenZFit offline?',
              'Most features require an internet connection for:\n'
              '• Body scan processing\n'
              '• AI recommendations\n'
              '• Syncing data\n\n'
              'However, measurement predictions can work offline after the initial scan is processed.',
            ),

            _buildFAQItem(
              'Is my data secure?',
              'Yes! We take security seriously:\n'
              '• All data is encrypted\n'
              '• Photos stored securely in Cloudinary\n'
              '• Firebase Authentication for login\n'
              '• Regular security audits\n\n'
              'See our Privacy Policy for details.',
            ),

            _buildFAQItem(
              'How do I delete my account?',
              'To delete your account:\n'
              '1. Contact support at support@genzfit.com\n'
              '2. Request account deletion\n'
              '3. We will process within 48 hours\n\n'
              'Note: This will permanently delete all your data including body scans, measurements, and profile information.',
            ),

            const SizedBox(height: 32),

            // Troubleshooting Section
            const Text(
              'Troubleshooting',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            _buildTroubleshootingItem(
              'Camera not working',
              '• Check app permissions in device settings\n'
              '• Ensure camera is not being used by another app\n'
              '• Restart the app\n'
              '• Update to latest version',
              Icons.camera_alt,
            ),

            _buildTroubleshootingItem(
              'Photos not uploading',
              '• Check internet connection\n'
              '• Ensure sufficient storage space\n'
              '• Try smaller photo size\n'
              '• Restart the app',
              Icons.cloud_upload,
            ),

            _buildTroubleshootingItem(
              'Measurements seem incorrect',
              '• Retake scan in better lighting\n'
              '• Stand in correct pose (arms slightly away)\n'
              '• Enter accurate height/weight/age\n'
              '• Ensure camera is at waist level',
              Icons.straighten,
            ),

            _buildTroubleshootingItem(
              'App crashes or freezes',
              '• Update to latest version\n'
              '• Clear app cache\n'
              '• Restart your device\n'
              '• Reinstall the app if needed',
              Icons.bug_report,
            ),

            const SizedBox(height: 32),

            // Contact Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Still Need Help?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildContactItem(Icons.email, 'Email', 'support@genzfit.com'),
                  _buildContactItem(Icons.access_time, 'Response Time', 'Within 48 hours'),
                  _buildContactItem(Icons.language, 'Website', 'www.genzfit.com'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          iconColor: AppColors.accent,
          collapsedIconColor: AppColors.textSecondary,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingItem(String title, String solution, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  solution,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
