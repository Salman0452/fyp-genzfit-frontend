import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

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
      Helpers.showSnackBar(context, 'Please select your fitness goal', isError: true);
      return;
    }

    if (widget.role == UserRole.trainer && _selectedExpertise.isEmpty) {
      Helpers.showSnackBar(context, 'Please select at least one expertise', isError: true);
      return;
    }

    if (widget.role == UserRole.trainer && _hourlyRateController.text.isEmpty) {
      Helpers.showSnackBar(context, 'Please enter your hourly rate', isError: true);
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: widget.role,
      goals: _selectedGoal,
      expertise: _selectedExpertise.isEmpty ? null : _selectedExpertise,
      hourlyRate: _hourlyRateController.text.isEmpty
          ? null
          : double.tryParse(_hourlyRateController.text),
    );

    if (!mounted) return;

    if (success) {
      Helpers.showSnackBar(context, 'Account created successfully!');
      
      // Navigate based on role
      if (widget.role == UserRole.client) {
        Navigator.pushReplacementNamed(context, '/client-home');
      } else if (widget.role == UserRole.trainer) {
        Navigator.pushReplacementNamed(context, '/trainer-home');
      }
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.error ?? 'Sign up failed',
        isError: true,
      );
    }
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create ${widget.role == UserRole.client ? 'Client' : 'Trainer'} Account',
                  style: const TextStyle(
                    color: AppConstants.textWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                const Text(
                  'Join GenZFit and start your fitness journey',
                  style: TextStyle(
                    color: AppConstants.textGray,
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
                  const Text(
                    'Fitness Goal',
                    style: TextStyle(
                      color: AppConstants.textWhite,
                      fontSize: AppConstants.fontMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _goals.map((goal) {
                      final isSelected = _selectedGoal == goal;
                      return ChoiceChip(
                        label: Text(_formatGoalName(goal)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGoal = selected ? goal : null;
                          });
                        },
                        backgroundColor: AppConstants.charcoalGray,
                        selectedColor: AppConstants.primaryGold,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppConstants.primaryBlack
                              : AppConstants.textWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Trainer-specific fields
                if (widget.role == UserRole.trainer) ...[
                  const Text(
                    'Expertise',
                    style: TextStyle(
                      color: AppConstants.textWhite,
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
                        backgroundColor: AppConstants.charcoalGray,
                        selectedColor: AppConstants.primaryGold,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppConstants.primaryBlack
                              : AppConstants.textWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  CustomTextField(
                    label: 'Hourly Rate (\$)',
                    hint: 'Enter your hourly rate',
                    controller: _hourlyRateController,
                    prefixIcon: Icons.attach_money,
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
                const SizedBox(height: AppConstants.paddingMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: AppConstants.textGray,
                        fontSize: AppConstants.fontMedium,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppConstants.primaryGold,
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
