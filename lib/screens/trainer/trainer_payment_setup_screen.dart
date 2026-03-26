import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bank_details_model.dart';
import '../../services/payment_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class TrainerPaymentSetupScreen extends StatefulWidget {
  const TrainerPaymentSetupScreen({Key? key}) : super(key: key);

  @override
  State<TrainerPaymentSetupScreen> createState() =>
      _TrainerPaymentSetupScreenState();
}

class _TrainerPaymentSetupScreenState extends State<TrainerPaymentSetupScreen> {
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _accountHolderController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ibanController;
  late TextEditingController _phoneNumberController;

  String _selectedTransferMethod = 'bank_transfer';
  bool _isDefault = true;
  bool _isLoading = false;
  bool _isLoadingBankDetails = false;

  List<BankDetailsModel> _bankDetails = [];

  @override
  void initState() {
    super.initState();
    _accountHolderController = TextEditingController();
    _bankNameController = TextEditingController();
    _accountNumberController = TextEditingController();
    _ibanController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _loadBankDetails();
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ibanController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBankDetails() async {
    setState(() => _isLoadingBankDetails = true);
    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;

      final details = await _paymentService.getTrainerBankDetails(user.id);
      setState(() => _bankDetails = details);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bank details: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingBankDetails = false);
    }
  }

  Future<void> _submitBankDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;

      await _paymentService.saveBankDetails(
        trainerId: user.id,
        accountHolderName: _accountHolderController.text.trim(),
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        iban: _ibanController.text.trim().isEmpty
            ? null
            : _ibanController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isEmpty
            ? null
            : _phoneNumberController.text.trim(),
        transferMethod: _selectedTransferMethod,
        isDefault: _isDefault,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Bank details saved! Waiting for admin verification.'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
          ),
        );
        _clearForm();
        await _loadBankDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bank details: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _accountHolderController.clear();
    _bankNameController.clear();
    _accountNumberController.clear();
    _ibanController.clear();
    _phoneNumberController.clear();
    setState(() {
      _selectedTransferMethod = 'bank_transfer';
      _isDefault = _bankDetails.isEmpty;
    });
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
          'Payment Setup',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoadingBankDetails
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saved bank details section
                  if (_bankDetails.isNotEmpty) ...[
                    const Text(
                      'Saved Bank Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._bankDetails
                        .map((detail) => _buildBankDetailCard(detail)),
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.charcoal),
                    const SizedBox(height: 24),
                  ],

                  // Add new bank details form
                  const Text(
                    'Add New Bank Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account holder name
                        TextFormField(
                          controller: _accountHolderController,
                          decoration: InputDecoration(
                            labelText: 'Account Holder Name',
                            hintText: 'Your full name',
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2A2A2A)
                                    : AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.charcoal,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.charcoal,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.brandGreen
                                    : AppColors.brandGreenDeep,
                                width: 2,
                              ),
                            ),
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter account holder name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Transfer method selector
                        const Text(
                          'Transfer Method',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTransferMethodSelector(),
                        const SizedBox(height: 16),

                        // Bank name (conditional - hide for Jazz/Easypaisa)
                        if (_selectedTransferMethod != 'jazz_cash' &&
                            _selectedTransferMethod != 'easypaisa')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _bankNameController,
                                decoration: InputDecoration(
                                  labelText: 'Bank Name',
                                  hintText: 'e.g., UBL, ABL, Meezan Bank',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF2A2A2A)
                                      : AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.brandGreen
                                          : AppColors.brandGreenDeep,
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                validator: (value) {
                                  if (_selectedTransferMethod ==
                                          'bank_transfer' &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Please enter bank name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Account number (conditional)
                        if (_selectedTransferMethod != 'jazz_cash' &&
                            _selectedTransferMethod != 'easypaisa')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _accountNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Account Number',
                                  hintText: '16-18 digits',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF2A2A2A)
                                      : AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.brandGreen
                                          : AppColors.brandGreenDeep,
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                validator: (value) {
                                  if (_selectedTransferMethod ==
                                          'bank_transfer' &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Please enter account number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // IBAN (optional)
                        if (_selectedTransferMethod == 'bank_transfer')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _ibanController,
                                decoration: InputDecoration(
                                  labelText: 'IBAN (Optional)',
                                  hintText: 'PKxx...',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF2A2A2A)
                                      : AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.brandGreen
                                          : AppColors.brandGreenDeep,
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Phone number (for Jazz/Easypaisa)
                        if (_selectedTransferMethod == 'jazz_cash' ||
                            _selectedTransferMethod == 'easypaisa')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _phoneNumberController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: '+923XXXXXXXXX',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF2A2A2A)
                                      : AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.brandGreen
                                          : AppColors.brandGreenDeep,
                                      width: 2,
                                    ),
                                  ),
                                  labelStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                                validator: (value) {
                                  if ((_selectedTransferMethod == 'jazz_cash' ||
                                          _selectedTransferMethod ==
                                              'easypaisa') &&
                                      (value == null || value.trim().isEmpty)) {
                                    return 'Please enter phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Set as default checkbox
                        if (_bankDetails.isNotEmpty)
                          CheckboxListTile(
                            value: _isDefault,
                            onChanged: (value) {
                              setState(() => _isDefault = value ?? false);
                            },
                            title: const Text(
                              'Set as default payout method',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            activeColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.brandGreen
                                    : AppColors.brandGreenDeep,
                            checkColor: AppColors.background,
                          ),

                        const SizedBox(height: 24),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitBankDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.brandGreen
                                  : AppColors.brandGreenDeep,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              disabledBackgroundColor: AppColors.muted,
                            ),
                            child: _isLoading
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
                                    'Save Bank Details',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.background,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Info card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.info.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Verification Required',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Admin will verify your bank details within 24 hours.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTransferMethodSelector() {
    final methods = [
      ('jazz_cash', 'Jazz Cash', Icons.money),
      ('easypaisa', 'EasyPaisa', Icons.account_balance_wallet),
      ('bank_transfer', 'Bank Transfer', Icons.account_balance),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: methods
          .map((method) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _selectedTransferMethod == method.$1
                      ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          .withOpacity(0.1)
                      : Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A2A)
                          : AppColors.surface,
                  border: Border.all(
                    color: _selectedTransferMethod == method.$1
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep)
                        : AppColors.charcoal,
                    width: _selectedTransferMethod == method.$1 ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  onTap: () {
                    setState(() => _selectedTransferMethod = method.$1);
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: Icon(
                    method.$3,
                    color: _selectedTransferMethod == method.$1
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep)
                        : AppColors.textSecondary,
                  ),
                  title: Text(
                    method.$2,
                    style: TextStyle(
                      color: _selectedTransferMethod == method.$1
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep)
                          : AppColors.textPrimary,
                      fontWeight: _selectedTransferMethod == method.$1
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _selectedTransferMethod == method.$1
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.brandGreen
                              : AppColors.brandGreenDeep,
                        )
                      : null,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildBankDetailCard(BankDetailsModel detail) {
    final statusColor =
        detail.verificationStatus == BankVerificationStatus.verified
            ? (Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep)
            : detail.verificationStatus == BankVerificationStatus.rejected
                ? AppColors.error
                : AppColors.warning;

    final statusLabel = detail.verificationStatus.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : AppColors.surface,
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          detail.bankName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (detail.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.brandGreen
                                      : AppColors.brandGreenDeep)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.brandGreen
                                        : AppColors.brandGreenDeep)
                                    .withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              'Default',
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.brandGreen
                                    : AppColors.brandGreenDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail.maskedAccountNumber,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (detail.rejectionReason != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 150,
                      child: Text(
                        'Reason: ${detail.rejectionReason}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 10,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
