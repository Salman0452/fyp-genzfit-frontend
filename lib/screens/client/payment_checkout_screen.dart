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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        elevation: 0,
        title: const Text(
          'Payment Checkout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session details card
            _buildSessionDetailsCard(),
            const SizedBox(height: 24),

            // Payment breakdown
            _buildPaymentBreakdown(),
            const SizedBox(height: 24),

            // Bank account details section
            const Text(
              'Transfer to Bank Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildBankDetailsCard(),
            const SizedBox(height: 24),

            // Receipt upload section
            const Text(
              'Upload Payment Receipt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildReceiptUploadSection(),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                  disabledBackgroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.background,
                          ),
                        ),
                      )
                    : const Text(
                        'Submit Payment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.background,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please ensure the receipt clearly shows the amount, beneficiary, and transaction date.',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : AppColors.surface,
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(widget.trainer.avatarUrl ?? ''),
                    fit: BoxFit.cover,
                    onError: (_, __) => const Icon(Icons.person),
                  ),
                ),
                child: widget.trainer.avatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.muted)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trainer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.trainer.role.toString().split('.').last,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : AppColors.surface,
        border: Border.all(color: AppColors.charcoal),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildBreakdownRow(
            'Session Fee',
            'PKR ${widget.sessionAmount.toStringAsFixed(0)}',
            false,
          ),
          const SizedBox(height: 12),
          Divider(
            color: AppColors.charcoal,
            height: 1,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            'Platform Fee (${(_commissionRate * 100).toStringAsFixed(0)}%)',
            'PKR ${_platformFee.toStringAsFixed(0)}',
            false,
            color: AppColors.muted,
          ),
          const SizedBox(height: 8),
          _buildBreakdownRow(
            'Trainer Receives',
            'PKR ${_trainerAmount.toStringAsFixed(0)}',
            true,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    String amount,
    bool isHighlight, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: color ?? AppColors.textSecondary,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBankDetailsCard() {
    return FutureBuilder(
      future: _paymentService.getTrainerDefaultBankDetails(widget.trainer.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : AppColors.surface,
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Unable to load bank details. Please try again later.',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        final bankDetails = snapshot.data;

        if (bankDetails == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : AppColors.surface,
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Trainer has not set up bank details yet.',
              style: TextStyle(color: AppColors.warning),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : AppColors.surface,
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account holder name
              _buildDetailRow(
                'Account Holder',
                bankDetails.accountHolderName,
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.charcoal, height: 1),
              const SizedBox(height: 16),

              // Bank Name
              _buildDetailRow(
                'Bank Name',
                bankDetails.bankName,
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.charcoal, height: 1),
              const SizedBox(height: 16),

              // IBAN (if available)
              if (bankDetails.iban != null && bankDetails.iban!.isNotEmpty)
                Column(
                  children: [
                    _buildDetailRow(
                      'IBAN',
                      bankDetails.iban!,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.charcoal, height: 1),
                    const SizedBox(height: 16),
                  ],
                ),

              // Account Number
              _buildDetailRow(
                'Account Number',
                bankDetails.maskedAccountNumber,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptUploadSection() {
    if (_receiptImage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _receiptImage!,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickReceiptImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Change Image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _receiptImage = null),
                  icon: const Icon(Icons.close),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : AppColors.surface,
            border: Border.all(
              color: AppColors.accent.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.image_outlined,
                size: 48,
                color: AppColors.accent.withOpacity(0.6),
              ),
              const SizedBox(height: 12),
              const Text(
                'Upload Payment Receipt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Screenshot or photo of your payment confirmation',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickReceiptImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('From Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.2),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takeReceiptScreenshot,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.2),
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
