import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() {
        _emailSent = true;
      });
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.error ?? 'Failed to send reset email',
        isError: true,
      );
    }
  }

  void _returnToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppConstants.primaryBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: _emailSent ? _buildSuccessView() : _buildEmailForm(authProvider),
        ),
      ),
    );
  }

  Widget _buildEmailForm(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.paddingXLarge),
          
          // Icon
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppConstants.primaryGold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 50,
                color: AppConstants.primaryGold,
              ),
            ),
          ),
          
          const SizedBox(height: AppConstants.paddingXLarge),
          
          const Text(
            'Forgot Password?',
            style: TextStyle(
              color: AppConstants.textWhite,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          const Text(
            "Don't worry! Enter your email address and we'll send you a link to reset your password.",
            style: TextStyle(
              color: AppConstants.textGray,
              fontSize: AppConstants.fontLarge,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: AppConstants.paddingXLarge),
          
          CustomTextField(
            label: 'Email Address',
            hint: 'Enter your email',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
          ),
          
          const SizedBox(height: AppConstants.paddingXLarge),
          
          CustomButton(
            text: 'Send Reset Link',
            onPressed: _handleSendResetEmail,
            isLoading: authProvider.isLoading,
            icon: Icons.send,
          ),
          
          const SizedBox(height: AppConstants.paddingMedium),
          
          Center(
            child: TextButton(
              onPressed: _returnToLogin,
              child: const Text(
                'Back to Login',
                style: TextStyle(
                  color: AppConstants.primaryGold,
                  fontSize: AppConstants.fontLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: AppConstants.paddingXLarge * 2),
        
        // Success Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.successGreen.withOpacity(0.2),
                AppConstants.successGreen.withOpacity(0.1),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read,
            size: 60,
            color: AppConstants.successGreen,
          ),
        ),
        
        const SizedBox(height: AppConstants.paddingXLarge),
        
        const Text(
          'Check Your Email!',
          style: TextStyle(
            color: AppConstants.textWhite,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: AppConstants.paddingMedium),
        
        Text(
          'We\'ve sent a password reset link to:',
          style: const TextStyle(
            color: AppConstants.textGray,
            fontSize: AppConstants.fontLarge,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: AppConstants.paddingSmall),
        
        Text(
          _emailController.text.trim(),
          style: const TextStyle(
            color: AppConstants.primaryGold,
            fontSize: AppConstants.fontLarge,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: AppConstants.paddingXLarge),
        
        // Instructions
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          decoration: BoxDecoration(
            color: AppConstants.charcoalGray,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: AppConstants.accentGray,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Next Steps:',
                style: TextStyle(
                  color: AppConstants.textWhite,
                  fontSize: AppConstants.fontLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              _buildStep('1', 'Check your email inbox'),
              const SizedBox(height: AppConstants.paddingSmall),
              _buildStep('2', 'Click the reset link in the email'),
              const SizedBox(height: AppConstants.paddingSmall),
              _buildStep('3', 'Enter your new password'),
              const SizedBox(height: AppConstants.paddingSmall),
              _buildStep('4', 'Return here to login'),
            ],
          ),
        ),
        
        const SizedBox(height: AppConstants.paddingXLarge),
        
        // Didn't receive email?
        const Text(
          "Didn't receive the email?",
          style: TextStyle(
            color: AppConstants.textGray,
            fontSize: AppConstants.fontMedium,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Text(
          '• Check your spam/junk folder\n• Make sure the email address is correct\n• Wait a few minutes and check again',
          style: const TextStyle(
            color: AppConstants.textDarkGray,
            fontSize: AppConstants.fontMedium,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: AppConstants.paddingXLarge),
        
        // Resend button
        CustomButton(
          text: 'Resend Email',
          onPressed: () {
            setState(() {
              _emailSent = false;
            });
          },
          isOutlined: true,
          icon: Icons.refresh,
        ),
        
        const SizedBox(height: AppConstants.paddingMedium),
        
        CustomButton(
          text: 'Back to Login',
          onPressed: _returnToLogin,
          backgroundColor: AppConstants.primaryGold,
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppConstants.primaryGold,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: AppConstants.primaryBlack,
                fontSize: AppConstants.fontSmall,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Text(
          text,
          style: const TextStyle(
            color: AppConstants.textGray,
            fontSize: AppConstants.fontMedium,
          ),
        ),
      ],
    );
  }
}
