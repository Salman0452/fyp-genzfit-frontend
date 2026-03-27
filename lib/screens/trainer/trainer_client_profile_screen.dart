import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/models/measurement_model.dart';
import 'package:genzfit/models/transaction_model.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/loading_widget.dart';

class TrainerClientProfileScreen extends StatefulWidget {
  final UserModel client;
  final String sessionId;

  const TrainerClientProfileScreen({
    super.key,
    required this.client,
    required this.sessionId,
  });

  @override
  State<TrainerClientProfileScreen> createState() =>
      _TrainerClientProfileScreenState();
}

class _TrainerClientProfileScreenState
    extends State<TrainerClientProfileScreen> {
  bool _isLoadingMeasurements = true;
  List<MeasurementModel> _measurements = [];
  bool _hasValidPayment = false;

  @override
  void initState() {
    super.initState();
    _checkPaymentAndLoadData();
  }

  Future<void> _checkPaymentAndLoadData() async {
    try {
      // Check if client has valid payment for current month
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('clientId', isEqualTo: widget.client.id)
          .where('sessionId', isEqualTo: widget.sessionId)
          .get();

      if (transactionsSnapshot.docs.isNotEmpty) {
        final latestDoc = transactionsSnapshot.docs.first;
        final transaction = TransactionModel.fromFirestore(latestDoc);

        // Check if payment is verified and within current month
        if (transaction.status == TransactionStatus.verified) {
          final now = DateTime.now();
          final paymentDate = transaction.createdAt;
          final nextMonth = DateTime(now.year, now.month + 1, paymentDate.day);

          // Payment is valid if it's verified and we're within the current month
          if (now.isBefore(nextMonth)) {
            setState(() => _hasValidPayment = true);
            await _loadMeasurements();
          }
        }
      }

      setState(() => _isLoadingMeasurements = false);
    } catch (e) {
      print('Error checking payment: $e');
      setState(() => _isLoadingMeasurements = false);
    }
  }

  Future<void> _loadMeasurements() async {
    try {
      final measurementsSnapshot = await FirebaseFirestore.instance
          .collection('measurements')
          .where('userId', isEqualTo: widget.client.id)
          .orderBy('date', descending: true)
          .get();

      final measurements = measurementsSnapshot.docs
          .map((doc) => MeasurementModel.fromFirestore(doc))
          .toList();

      setState(() => _measurements = measurements);
    } catch (e) {
      print('Error loading measurements: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.client.name),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _isLoadingMeasurements
          ? const Center(child: LoadingWidget())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client header
                  _buildClientHeader(),
                  const SizedBox(height: 24),

                  // Client info
                  _buildClientInfo(),
                  const SizedBox(height: 24),

                  // Payment status
                  _buildPaymentStatus(),
                  const SizedBox(height: 24),

                  // Measurements section
                  if (_hasValidPayment) ...[
                    Text(
                      'Client Measurements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_measurements.isEmpty)
                      Center(
                        child: Text(
                          'No measurements recorded yet',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B0B0)
                                    : AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _measurements.length,
                        itemBuilder: (context, index) {
                          final measurement = _measurements[index];
                          return _buildMeasurementCard(measurement);
                        },
                      ),
                  ] else
                    _buildUnpaidMessage(),
                ],
              ),
            ),
    );
  }

  Widget _buildClientHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen.withOpacity(0.3)
              : AppColors.brandGreenDeep.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen.withOpacity(0.2)
                  : AppColors.brandGreenDeep.withOpacity(0.2),
            ),
            child: widget.client.avatarUrl != null &&
                    widget.client.avatarUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: CachedNetworkImage(
                      imageUrl: widget.client.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[700]),
                      errorWidget: (context, url, error) => Center(
                        child: Text(
                          widget.client.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      widget.client.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          // Client info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.client.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.client.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.client.goals != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen.withOpacity(0.2)
                          : AppColors.brandGreenDeep.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatGoal(widget.client.goals!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Email', widget.client.email),
          const SizedBox(height: 12),
          if (widget.client.goals != null)
            _buildInfoRow('Goal', _formatGoal(widget.client.goals!)),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Member Since',
            DateFormat('MMM dd, yyyy').format(widget.client.createdAt),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Status', widget.client.status.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasValidPayment
            ? AppColors.success.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: _hasValidPayment
              ? AppColors.success.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasValidPayment ? Icons.check_circle : Icons.info,
            color: _hasValidPayment ? AppColors.success : AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasValidPayment ? 'Payment Verified' : 'Payment Pending',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _hasValidPayment
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hasValidPayment
                      ? 'Payment verified for this month. You can view client measurements.'
                      : 'Waiting for payment verification. Measurements will be visible once payment is confirmed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0B0B0)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpaidMessage() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          Text(
            'Measurements Locked',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment must be verified to view client measurements. Once the admin confirms the payment for this month, you\'ll have access to all client data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFB0B0B0)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(MeasurementModel measurement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.brandGreen.withOpacity(0.2)
              : AppColors.brandGreenDeep.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(measurement.date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen.withOpacity(0.2)
                      : AppColors.brandGreenDeep.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'BMI: ${measurement.bmi.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Body Measurements',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFB0B0B0)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: measurement.estimatedMeasurements.length,
            itemBuilder: (context, index) {
              final entries =
                  measurement.estimatedMeasurements.entries.toList();
              final key = entries[index].key;
              final value = entries[index].value;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen.withOpacity(0.1)
                      : AppColors.brandGreenDeep.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMeasurementKey(key),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0B0B0)
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(1)} cm',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Height: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                '${measurement.height} cm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'Weight: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                '${measurement.weight} kg',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB0B0B0)
                : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatGoal(String goal) {
    switch (goal) {
      case 'fitness':
        return 'General Fitness';
      case 'weightGain':
        return 'Weight Gain';
      case 'weightLoss':
        return 'Weight Loss';
      default:
        return goal;
    }
  }

  String _formatMeasurementKey(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
  }
}
