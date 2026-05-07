import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../onboarding/onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  final UserRole role;

  const SignupScreen({
    super.key,
    required this.role,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  String? _selectedGoal;
  final List<String> _selectedExpertise = [];

  final List<String> _goals = [
    AppConstants.goalFitness,
    AppConstants.goalWeightGain,
    AppConstants.goalWeightLoss,
  ];

  final List<String> _expertiseOptions = [
    'Weight Loss',
    'Muscle Building',
    'Yoga',
    'Cardio',
    'Strength Training',
    'Nutrition',
    'CrossFit',
    'Pilates',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate role-specific fields
    if (widget.role == UserRole.client && _selectedGoal == null) {
      Helpers.showSnackBar(context, 'Please select your fitness goal',
          isError: true);
      return;
    }

    if (widget.role == UserRole.trainer && _selectedExpertise.isEmpty) {
      Helpers.showSnackBar(context, 'Please select at least one expertise',
          isError: true);
      return;
    }

    if (widget.role == UserRole.trainer && _hourlyRateController.text.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter your monthly rate (PKR)',
          isError: true);
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // Step 1: Create account and send email verification link
    final authProvider = context.read<AuthProvider>();

    try {
      // Create account (mark email as unverified until link is clicked)
      final success = await authProvider.signUp(
        email: email,
        password: password,
        name: name,
        role: widget.role,
        goals: _selectedGoal,
        expertise: _selectedExpertise.isEmpty ? null : _selectedExpertise,
        hourlyRate: _hourlyRateController.text.isEmpty
            ? null
            : double.tryParse(_hourlyRateController.text),
        emailVerified: false, // Mark as unverified
      );

      if (!mounted) return;

      if (success) {
        final linkSent = await authProvider.sendEmailVerificationLink();

        if (!mounted) return;

        if (linkSent) {
          await authProvider.signOut();

          if (!mounted) return;

          Helpers.showSnackBar(
            context,
            'Verification link sent to $email. Verify your email and sign in.',
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        } else {
          Helpers.showSnackBar(
            context,
            authProvider.error ??
                'Failed to send verification email. Please try again.',
            isError: true,
          );
        }
      } else {
        Helpers.showSnackBar(
          context,
          authProvider.error ?? 'Sign up failed',
          isError: true,
        );
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _handleGoogleSignup() async {
    if (!_validateRoleSpecificFields()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle(
      role: widget.role,
      goals: _selectedGoal,
      expertise: _selectedExpertise.isEmpty ? null : _selectedExpertise,
      hourlyRate: _hourlyRateController.text.isEmpty
          ? null
          : double.tryParse(_hourlyRateController.text),
      nameOverride: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      if (authProvider.lastSocialAuthIsNewUser) {
        _navigateAfterSignup();
      } else {
        _navigateByRole(authProvider.currentUser);
      }
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.error ?? 'Google sign up failed',
        isError: true,
      );
    }
  }

  bool _validateRoleSpecificFields() {
    if (widget.role == UserRole.client && _selectedGoal == null) {
      Helpers.showSnackBar(
        context,
        'Please select your fitness goal',
        isError: true,
      );
      return false;
    }

    if (widget.role == UserRole.trainer && _selectedExpertise.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please select at least one expertise',
        isError: true,
      );
      return false;
    }

    if (widget.role == UserRole.trainer && _hourlyRateController.text.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please enter your monthly rate (PKR)',
        isError: true,
      );
      return false;
    }

    return true;
  }

  void _navigateAfterSignup() {
    if (widget.role == UserRole.client) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } else if (widget.role == UserRole.trainer) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/trainer-home', (route) => false);
    }
  }

  void _navigateByRole(UserModel? user) {
    if (user == null) return;

    if (user.role == UserRole.client) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/client-home',
        (route) => false,
      );
    } else if (user.role == UserRole.trainer) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/trainer-home',
        (route) => false,
      );
    } else if (user.role == UserRole.admin) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/admin-dashboard',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create ${widget.role == UserRole.client ? 'Client' : 'Trainer'} Account',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : Colors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  'Join GenZFit and start your fitness journey',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : Colors.grey[600],
                    fontSize: AppConstants.fontLarge,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXLarge),
                CustomTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  validator: Validators.validateName,
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                CustomTextField(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: _emailController,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                CustomTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                CustomTextField(
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                // Client-specific fields
                if (widget.role == UserRole.client) ...[
                  Text(
                    'Fitness Goal',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : Colors.black,
                      fontSize: AppConstants.fontMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _goals.map((goal) {
                      final isSelected = _selectedGoal == goal;
                      final isDarkMode =
                          Theme.of(context).brightness == Brightness.dark;
                      return ChoiceChip(
                        label: Text(_formatGoalName(goal)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGoal = selected ? goal : null;
                          });
                        },
                        backgroundColor: isDarkMode
                            ? const Color(0xFF1A1A1A)
                            : AppConstants.charcoalGray,
                        selectedColor: isDarkMode
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppConstants.primaryBlack
                              : isDarkMode
                                  ? const Color(0xFFFFFFFF)
                                  : AppConstants.textWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Trainer-specific fields
                if (widget.role == UserRole.trainer) ...[
                  Text(
                    'Expertise',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppConstants.textWhite,
                      fontSize: AppConstants.fontMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _expertiseOptions.map((expertise) {
                      final isSelected = _selectedExpertise.contains(expertise);
                      final isDarkMode =
                          Theme.of(context).brightness == Brightness.dark;
                      return FilterChip(
                        label: Text(expertise),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedExpertise.add(expertise);
                            } else {
                              _selectedExpertise.remove(expertise);
                            }
                          });
                        },
                        backgroundColor: isDarkMode
                            ? const Color(0xFF1A1A1A)
                            : AppConstants.charcoalGray,
                        selectedColor: isDarkMode
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppConstants.primaryBlack
                              : isDarkMode
                                  ? const Color(0xFFFFFFFF)
                                  : AppConstants.textWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  CustomTextField(
                    label: 'Monthly Rate (PKR)',
                    hint: 'Enter your monthly rate in PKR',
                    controller: _hourlyRateController,
                    prefixIcon: Icons.payments_outlined,
                    keyboardType: TextInputType.number,
                    validator: Validators.validateHourlyRate,
                  ),
                ],

                const SizedBox(height: AppConstants.paddingXLarge),
                CustomButton(
                  text: 'Create Account',
                  onPressed: _handleSignup,
                  isLoading: authProvider.isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFDADADA),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Or sign up with',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB0B0B0)
                              : AppConstants.textGray,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFDADADA),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            authProvider.isLoading ? null : _handleGoogleSignup,
                        icon: const Icon(Icons.g_mobiledata, size: 22),
                        label: const Text(
                          'Google',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0)
                            : AppConstants.textGray,
                        fontSize: AppConstants.fontMedium,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                          fontSize: AppConstants.fontMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatGoalName(String goal) {
    switch (goal) {
      case AppConstants.goalFitness:
        return 'General Fitness';
      case AppConstants.goalWeightGain:
        return 'Weight Gain';
      case AppConstants.goalWeightLoss:
        return 'Weight Loss';
      default:
        return goal;
    }
  }
}
