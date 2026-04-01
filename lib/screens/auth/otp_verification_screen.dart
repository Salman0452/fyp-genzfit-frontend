import 'package:flutter/material.dart';
import 'package:genzfit/services/otp_service.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/utils/helpers.dart';
import 'dart:async';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final Function(bool) onVerified;

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final OTPService _otpService = OTPService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;
  int _remainingSeconds = 300; // 5 minutes
  Timer? _expiryTimer;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _expiryTimer?.cancel();
          _showExpiredDialog();
        }
      });
    });
  }

  void _startResendCooldown() {
    _resendCooldown = 60; // 60 seconds cooldown
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _resendTimer?.cancel();
        }
      });
    });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('OTP Expired'),
        content: const Text('Your OTP has expired. Please request a new one.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleResendOTP();
            },
            child: const Text('Request New OTP'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerifyOTP() async {
    // Get entered OTP
    final enteredOTP = _controllers.map((c) => c.text).join();

    if (enteredOTP.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await _otpService.verifyOTP(
        email: widget.email,
        enteredOTP: enteredOTP,
      );

      if (!mounted) return;

      if (isValid) {
        _expiryTimer?.cancel();
        Helpers.showSnackBar(context, 'Email verified successfully!');
        widget.onVerified(true);
      } else {
        setState(() => _errorMessage = 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error verifying OTP: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResendOTP() async {
    setState(() => _isResending = true);

    try {
      final success = await _otpService.resendOTP(email: widget.email);

      if (!mounted) return;

      if (success) {
        Helpers.showSnackBar(context, 'New OTP sent to ${widget.email}');
        _startResendCooldown();

        // Reset fields and timer
        for (var controller in _controllers) {
          controller.clear();
        }
        setState(() {
          _remainingSeconds = 300;
          _errorMessage = '';
        });
        _expiryTimer?.cancel();
        _startExpiryTimer();

        // Focus on first field
        FocusScope.of(context).requestFocus(_focusNodes[0]);
      } else {
        Helpers.showSnackBar(
          context,
          'Too many resend attempts. Please try again later.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Error resending OTP: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _onOTPDigitChanged(String value, int index) {
    if (value.isEmpty) {
      if (index > 0) {
        // Move to previous field if backspaced
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }
    } else if (value.length == 1) {
      setState(() => _errorMessage = '');
      if (index < 5) {
        // Move to next field
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        // Last field filled, can verify
        _handleVerifyOTP();
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: _isLoading
            ? null
            : IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDarkMode ? const Color(0xFFFFFFFF) : Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Icon(
                Icons.mail_outline,
                size: 64,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreen,
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : Colors.black,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                'We sent a 6-digit code to',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandGreen,
                ),
              ),
              const SizedBox(height: AppConstants.paddingXLarge),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: !_isLoading,
                      inputFormatters: [
                        // Accept only digits
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _errorMessage.isNotEmpty
                                ? Colors.red
                                : (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF333333)
                                    : Colors.grey[300]!),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.brandGreen,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1A1A1A)
                                : Colors.grey[50],
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (value) => _onOTPDigitChanged(value, index),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Error Message
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: AppConstants.paddingLarge),

              // Expiry Timer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Code expires in ${_formatTime(_remainingSeconds)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _remainingSeconds < 60
                        ? Colors.red
                        : AppColors.brandGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingXLarge),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.brandGreen.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMedium),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0B0B0)
                          : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: _resendCooldown > 0 || _isResending
                        ? null
                        : _handleResendOTP,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend in $_resendCooldown s'
                          : 'Resend OTP',
                      style: TextStyle(
                        color: _resendCooldown > 0
                            ? Colors.grey[500]
                            : AppColors.brandGreen,
                        fontSize: 14,
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
    );
  }
}
