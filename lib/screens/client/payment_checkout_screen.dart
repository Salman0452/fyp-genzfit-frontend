import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_model.dart';
import '../../../services/payment_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';
import 'package:provider/provider.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final UserModel trainer;
  final double sessionAmount;
  final String sessionId;

  const PaymentCheckoutScreen({
    Key? key,
    required this.trainer,
    required this.sessionAmount,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final PaymentService _paymentService = PaymentService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  File? _receiptImage;
  bool _isUploading = false;
  String _transactionId = '';
  double _commissionRate = 0.10; // Default 10%, will be updated from Firestore
  double _platformFee = 0.0;
  double _trainerAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAmounts();
  }

  void _initializeAmounts() {
    _platformFee = widget.sessionAmount * _commissionRate;
    _trainerAmount = widget.sessionAmount - _platformFee;
    _loadCommissionRate();
  }

  Future<void> _loadCommissionRate() async {
    try {
      final settingsDoc = await _firestore
          .collection('platform_settings')
          .doc('commission')
          .get();
      if (settingsDoc.exists) {
        final rate = settingsDoc.data()?['rate'] as num?;
        if (rate != null) {
          setState(() {
            _commissionRate = rate.toDouble();
            _platformFee = widget.sessionAmount * _commissionRate;
            _trainerAmount = widget.sessionAmount - _platformFee;
          });
        }
      } else {
        // Set default values if not found
        setState(() {
          _platformFee = widget.sessionAmount * _commissionRate;
          _trainerAmount = widget.sessionAmount - _platformFee;
        });
      }
    } catch (e) {
      print('Error loading commission rate: $e');
      // Use default values
      setState(() {
        _platformFee = widget.sessionAmount * _commissionRate;
        _trainerAmount = widget.sessionAmount - _platformFee;
      });
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() => _receiptImage = File(pickedFile.path));
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _takeReceiptScreenshot() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() => _receiptImage = File(pickedFile.path));
      }
    } catch (e) {
      _showError('Failed to take screenshot: $e');
    }
  }

  Future<void> _submitPayment() async {
    if (_receiptImage == null) {
      _showError('Please upload a payment receipt');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Initiate payment transaction
      _transactionId = await _paymentService.initiatePayment(
        clientId: user.id,
        trainerId: widget.trainer.id,
        sessionId: widget.sessionId,
        sessionAmount: widget.sessionAmount,
      );

      // Upload receipt image
      await _paymentService.recordPaymentProof(
        transactionId: _transactionId,
        proofImage: _receiptImage!,
        paymentMethod: PaymentMethod.other,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showError('Payment submission failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        title: const Text(
          'Payment Submitted',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Receipt Uploaded',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your payment receipt has been submitted for verification.\n\nAdmin will verify within 24 hours and activate your session.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.charcoal),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTransactionRow('Transaction ID', _transactionId),
                        const SizedBox(height: 8),
                        _buildTransactionRow(
                          'Method',
                          'Bank Transfer',
                        ),
                        const SizedBox(height: 8),
                        _buildTransactionRow(
                          'Amount',
                          'PKR ${widget.sessionAmount.toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep this transaction ID for your records.',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, _transactionId);
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppColors.brandGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Checkout',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete your session booking',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: accentColor,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            const SizedBox(height: 28),

            // Session details card with enhanced design
            _buildSessionDetailsCard(),
            const SizedBox(height: 24),

            // Payment breakdown with gradient
            _buildPaymentBreakdown(),
            const SizedBox(height: 28),

            // Bank account details section
            _buildBankDetailsSection(),
            const SizedBox(height: 28),

            // Receipt upload section
            _buildReceiptUploadSection(),
            const SizedBox(height: 28),

            // Submit button with modern design
            _buildSubmitButton(accentColor),
            const SizedBox(height: 16),

            // Security info
            _buildSecurityInfo(accentColor),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        _buildProgressStep(1, 'Details', true, isDarkMode),
        Container(
          height: 2,
          width: 30,
          color: AppColors.brandGreen.withOpacity(0.3),
        ),
        _buildProgressStep(2, 'Payment', true, isDarkMode),
        Container(
          height: 2,
          width: 30,
          color: AppColors.brandGreen.withOpacity(0.2),
        ),
        _buildProgressStep(3, 'Confirm', false, isDarkMode),
      ],
    );
  }

  Widget _buildProgressStep(
      int step, String label, bool completed, bool isDarkMode) {
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? accentColor : accentColor.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: completed
                      ? (isDarkMode ? Colors.black : Colors.white)
                      : accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: completed
                  ? accentColor
                  : (isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetailsCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Session Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Trainer info with modern design
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      color: accentColor.withOpacity(0.1),
                      child: widget.trainer.avatarUrl != null
                          ? Image.network(
                              widget.trainer.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.person,
                                color: accentColor,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: accentColor,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.trainer.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? const Color(0xFFFFFFFF)
                              : AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Fitness Trainer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? const Color(0xFFB0B0B0)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Session details grid
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Session Type',
                  'Personal Training',
                  Icons.fitness_center_rounded,
                  accentColor,
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  'Duration',
                  '1 Hour',
                  Icons.schedule_rounded,
                  accentColor,
                  isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            'Date & Time',
            'Scheduled',
            Icons.calendar_today_rounded,
            accentColor,
            isDarkMode,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    bool isDarkMode, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color:
                  isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          // Session fee
          _buildBreakdownItem(
            'Session Fee',
            'PKR ${widget.sessionAmount.toStringAsFixed(0)}',
            Icons.credit_card_outlined,
            isDarkMode,
            accentColor,
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: isDarkMode
                ? const Color(0xFF3A3A3A)
                : accentColor.withOpacity(0.1),
          ),
          const SizedBox(height: 14),
          // Platform fee
          _buildBreakdownItem(
            'Platform Fee (${(_commissionRate * 100).toStringAsFixed(0)}%)',
            'PKR ${_platformFee.toStringAsFixed(0)}',
            Icons.percent_outlined,
            isDarkMode,
            accentColor,
            isSubtle: true,
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: isDarkMode
                ? const Color(0xFF3A3A3A)
                : accentColor.withOpacity(0.1),
          ),
          const SizedBox(height: 14),
          // Trainer receives
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trainer Receives',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PKR ${_trainerAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    String label,
    String amount,
    IconData icon,
    bool isDarkMode,
    Color accentColor, {
    bool isSubtle = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSubtle
                  ? (isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary)
                  : accentColor,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSubtle
                    ? (isDarkMode
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary)
                    : (isDarkMode
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isSubtle ? 13 : 14,
            fontWeight: FontWeight.w700,
            color: isSubtle
                ? (isDarkMode
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary)
                : (isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBankDetailsSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer Details',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>?>(
          future: _paymentService.getPlatformBankDetails(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: accentColor,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              print('Error loading bank details: ${snapshot.error}');
              return _buildErrorCard(
                'Unable to load bank details',
                'Error: ${snapshot.error.toString()}',
                isDarkMode,
              );
            }

            final bankDetails = snapshot.data;

            if (bankDetails == null) {
              return _buildWarningCard(
                'Bank Account Not Set',
                'Platform bank details have not been configured yet.',
                isDarkMode,
              );
            }

            final bankName = bankDetails['bankName'] as String? ?? '';
            if (bankName.isEmpty) {
              return _buildWarningCard(
                'Bank Account Not Set',
                'Platform bank details have not been configured yet.',
                isDarkMode,
              );
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF262626)
                    : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                border: Border.all(
                  color: accentColor.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.2)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildBankDetailField(
                    'Account Holder',
                    (bankDetails['accountHolder'] as String?) ?? '',
                    Icons.person_outline,
                    accentColor,
                    isDarkMode,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: isDarkMode
                        ? const Color(0xFF3A3A3A)
                        : accentColor.withOpacity(0.1),
                  ),
                  const SizedBox(height: 14),
                  _buildBankDetailField(
                    'Bank Name',
                    bankName,
                    Icons.account_balance_outlined,
                    accentColor,
                    isDarkMode,
                  ),
                  const SizedBox(height: 14),
                  if (((bankDetails['iban'] as String?) ?? '').isNotEmpty)
                    Column(
                      children: [
                        Container(
                          height: 1,
                          color: isDarkMode
                              ? const Color(0xFF3A3A3A)
                              : accentColor.withOpacity(0.1),
                        ),
                        const SizedBox(height: 14),
                        _buildBankDetailField(
                          'IBAN',
                          (bankDetails['iban'] as String?) ?? '',
                          Icons.numbers_outlined,
                          accentColor,
                          isDarkMode,
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  Container(
                    height: 1,
                    color: isDarkMode
                        ? const Color(0xFF3A3A3A)
                        : accentColor.withOpacity(0.1),
                  ),
                  const SizedBox(height: 14),
                  _buildBankDetailField(
                    'Account Number',
                    (bankDetails['accountNumber'] as String?) ?? '',
                    Icons.credit_card_outlined,
                    accentColor,
                    isDarkMode,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBankDetailField(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    bool isDarkMode,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: accentColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(
    String title,
    String message,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(
    String title,
    String message,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptUploadSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    if (_receiptImage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Receipt',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color:
                  isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              child: Image.file(
                _receiptImage!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickReceiptImage,
                  icon: Icon(Icons.edit_outlined, size: 18, color: accentColor),
                  label: Text(
                    'Change',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accentColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _receiptImage = null),
                  icon: const Icon(Icons.close_outlined, size: 18),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.error,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Receipt',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? const Color(0xFFFFFFFF) : AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF262626) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            border: Border.all(
              color: accentColor.withOpacity(0.15),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Upload Payment Receipt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Screenshot or photo of your payment confirmation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickReceiptImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text(
                  'From Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.12),
                  foregroundColor: accentColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takeReceiptScreenshot,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.12),
                  foregroundColor: accentColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color accentColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _submitPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          disabledBackgroundColor: accentColor.withOpacity(0.4),
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          shadowColor: accentColor.withOpacity(0.3),
        ),
        child: _isUploading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDarkMode ? Colors.black87 : Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isUploading ? Icons.hourglass_empty : Icons.check_circle,
                    color: isDarkMode ? Colors.black87 : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Complete Payment',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDarkMode ? Colors.black87 : Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityInfo(Color accentColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.success.withOpacity(0.08)
            : AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.success.withOpacity(isDarkMode ? 0.2 : 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_outlined,
            color: isDarkMode ? AppColors.success : AppColors.brandGreenDeep,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your payment information is secure and encrypted. Please ensure the receipt clearly shows the amount, beneficiary, and transaction date.',
              style: TextStyle(
                color:
                    isDarkMode ? AppColors.success : AppColors.brandGreenDeep,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
