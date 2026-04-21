import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminTrainerInsightsScreen extends StatelessWidget {
  final String trainerId;
  final Map<String, dynamic> trainerUserData;

  const AdminTrainerInsightsScreen({
    super.key,
    required this.trainerId,
    required this.trainerUserData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        title: Text(
          'Trainer Details',
          style: GoogleFonts.poppins(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildTrainerProfileSection(context),
          const SizedBox(height: 16),
          _buildPreferencesSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryText.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _safeText(trainerUserData['name']) == '-'
                ? '(Unnamed Trainer)'
                : _safeText(trainerUserData['name']),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _safeText(trainerUserData['email']),
            style: GoogleFonts.inter(color: secondaryText),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Role: ${_safeText(trainerUserData['role'])}'),
              _chip(context, 'Status: ${_safeText(trainerUserData['status'])}'),
              _chip(context, 'Email Verified: ${(trainerUserData['emailVerified'] == true) ? 'Yes' : 'No'}'),
              _chip(context, 'UID: $trainerId'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerProfileSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryText.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trainer Profile',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trainers')
                .doc(trainerId)
                .snapshots(),
            builder: (context, trainerDocSnapshot) {
              if (trainerDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }

              if (trainerDocSnapshot.hasError) {
                return Text(
                  'Failed to load trainer profile: ${trainerDocSnapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red),
                );
              }

              final directTrainerDoc =
                  trainerDocSnapshot.data?.data() as Map<String, dynamic>?;
              if (directTrainerDoc != null) {
                return _buildTrainerProfileContent(
                  context,
                  directTrainerDoc,
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('trainers')
                    .where('userId', isEqualTo: trainerId)
                    .limit(1)
                    .snapshots(),
                builder: (context, fallbackSnapshot) {
                  if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }

                  if (fallbackSnapshot.hasError) {
                    return Text(
                      'Failed to load trainer profile: ${fallbackSnapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red),
                    );
                  }

                  if (!fallbackSnapshot.hasData || fallbackSnapshot.data!.docs.isEmpty) {
                    return Text(
                      'No trainer profile found in trainers collection.',
                      style: GoogleFonts.inter(color: secondaryText),
                    );
                  }

                  final trainerDoc =
                      fallbackSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                  return _buildTrainerProfileContent(
                    context,
                    trainerDoc,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerProfileContent(
    BuildContext context,
    Map<String, dynamic> trainerDoc,
  ) {
    final expertise = _asStringList(trainerDoc['expertise']);
    final certifications = trainerDoc['certifications'] is List
        ? List<dynamic>.from(trainerDoc['certifications'] as List)
        : const [];
    final videoUrls = _asStringList(trainerDoc['videoUrls']);
    final availability = trainerDoc['availability'] is Map
        ? Map<String, dynamic>.from(trainerDoc['availability'] as Map)
        : <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKeyValue(context, 'Bio', _safeText(trainerDoc['bio'])),
        _buildKeyValue(
          context,
          'Verified Trainer',
          (trainerDoc['verified'] == true) ? 'Yes' : 'No',
        ),
        _buildKeyValue(
          context,
          'Hourly Rate',
          _toCurrency(trainerDoc['hourlyRate']),
        ),
        _buildKeyValue(
          context,
          'Monthly Rate',
          _toCurrency(
            trainerDoc['monthlyRate'] ?? trainerUserData['monthlyRate'],
          ),
        ),
        _buildKeyValue(
          context,
          'Rating',
          _toOneDecimal(trainerDoc['rating']),
        ),
        _buildKeyValue(
          context,
          'Clients',
          _toPlainNumber(trainerDoc['clients']),
        ),
        _buildKeyValue(
          context,
          'Total Earnings',
          _toCurrency(trainerDoc['totalEarnings']),
        ),
        const SizedBox(height: 10),
        _buildListSection(context, 'Expertise', expertise),
        const SizedBox(height: 10),
        _buildCertificationsSection(context, certifications),
        const SizedBox(height: 10),
        _buildListSection(context, 'Video URLs', videoUrls),
        const SizedBox(height: 10),
        _buildAvailabilitySection(context, availability),
        const SizedBox(height: 16),
        _buildVerificationActions(context, trainerDoc),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryText.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_preferences')
                .doc(trainerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  'Failed to load preferences: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red),
                );
              }

              final storedPrefs = snapshot.data?.data() as Map<String, dynamic>?;
              final userInlinePrefs = trainerUserData['preferences'] is Map<String, dynamic>
                  ? trainerUserData['preferences'] as Map<String, dynamic>
                  : <String, dynamic>{};
              final merged = <String, dynamic>{
                ...userInlinePrefs,
                ...?storedPrefs,
              };

              if (merged.isEmpty) {
                return Text(
                  'No preferences found for this trainer.',
                  style: GoogleFonts.inter(color: secondaryText),
                );
              }

              final entries = merged.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries
                    .where((entry) => _hasDisplayableValue(entry.value))
                    .map((entry) => _buildKeyValue(context, _humanizeKey(entry.key), _displayValue(entry.value)))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(
    BuildContext context,
    String title,
    List<String> values,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: secondaryText.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${values.length} item${values.length == 1 ? '' : 's'}',
          style: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 12,
          ),
        ),
        children: values.isEmpty
            ? [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No data',
                    style: GoogleFonts.inter(color: secondaryText),
                  ),
                ),
              ]
            : values
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '- $item',
                        style: GoogleFonts.inter(color: primaryText),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildCertificationsSection(
    BuildContext context,
    List<dynamic> certifications,
  ) {
    final normalized = certifications.map<Map<String, dynamic>>((item) {
      if (item is String) {
        return {
          'name': 'Certificate',
          'issuedBy': '-',
          'imageUrl': item,
          'dateAdded': null,
        };
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'name': _safeText(map['name']) == '-' ? 'Certificate' : _safeText(map['name']),
          'issuedBy': _safeText(map['issuedBy']),
          'imageUrl': _safeText(map['imageUrl']),
          'dateAdded': map['dateAdded'],
        };
      }
      return {
        'name': 'Certificate',
        'issuedBy': '-',
        'imageUrl': '-',
        'dateAdded': null,
      };
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: secondaryText.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(
          'Certifications',
          style: GoogleFonts.poppins(
            color: primaryText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${normalized.length} item${normalized.length == 1 ? '' : 's'}',
          style: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 12,
          ),
        ),
        children: normalized.isEmpty
            ? [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No certifications uploaded.',
                    style: GoogleFonts.inter(color: secondaryText),
                  ),
                ),
              ]
            : normalized
                .map(
                  (cert) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: secondaryText.withOpacity(0.22)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _safeText(cert['name']),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Issued By: ${_safeText(cert['issuedBy'])}',
                          style: GoogleFonts.inter(color: secondaryText),
                        ),
                        if (_safeText(cert['imageUrl']) != '-') ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showCertificatePreview(
                              context,
                              _safeText(cert['imageUrl']),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                color: secondaryText.withOpacity(0.08),
                                child: Image.network(
                                  _safeText(cert['imageUrl']),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) {
                                      return child;
                                    }
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: progress.expectedTotalBytes == null
                                            ? null
                                            : progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!,
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        'Image could not be loaded',
                                        style: GoogleFonts.inter(
                                          color: secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _safeText(cert['imageUrl']),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (cert['dateAdded'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Added: ${_asDateFromAny(cert['dateAdded'])}',
                            style: GoogleFonts.inter(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildAvailabilitySection(
    BuildContext context,
    Map<String, dynamic> availability,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    final entries = availability.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: secondaryText.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(
          'Availability',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${entries.length} day${entries.length == 1 ? '' : 's'} configured',
          style: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 12,
          ),
        ),
        children: entries.isEmpty
            ? [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No availability set.',
                    style: GoogleFonts.inter(color: secondaryText),
                  ),
                ),
              ]
            : entries
                .map((entry) => _buildKeyValue(context, _humanizeKey(entry.key), _displayValue(entry.value)))
                .toList(),
      ),
    );
  }

  Widget _buildKeyValue(BuildContext context, String key, dynamic value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              key,
              style: GoogleFonts.inter(
                color: secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _displayValue(value),
              style: GoogleFonts.inter(color: primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationActions(
    BuildContext context,
    Map<String, dynamic> trainerDoc,
  ) {
    final isVerified = trainerDoc['verified'] == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => isVerified
                ? _revokeVerification(context)
                : _approveTrainer(context),
            icon: Icon(isVerified ? Icons.remove_circle_outline : Icons.verified),
            label: Text(
              isVerified ? 'Revoke Verification' : 'Verify Trainer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isVerified ? Colors.red : primaryColor,
              foregroundColor: isDark
                  ? const Color(0xFF1A1A1A)
                  : AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.brandGreen : AppColors.brandGreenDeep)
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const [];
  }

  String _toCurrency(dynamic value) {
    final number = (value as num?)?.toDouble();
    if (number == null) return '-';
    return number.toStringAsFixed(0);
  }

  String _toOneDecimal(dynamic value) {
    final number = (value as num?)?.toDouble();
    if (number == null) return '-';
    return number.toStringAsFixed(1);
  }

  String _toPlainNumber(dynamic value) {
    final number = value as num?;
    if (number == null) return '-';
    return number.toString();
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String _displayValue(dynamic value) {
    if (value == null) {
      return '-';
    }
    if (value is List) {
      return value.isEmpty ? '-' : value.join(', ');
    }
    if (value is Map) {
      if (value.isEmpty) {
        return '-';
      }
      return value.entries
          .map((e) => '${_humanizeKey(e.key.toString())}: ${e.value}')
          .join(' | ');
    }
    return value.toString();
  }

  bool _hasDisplayableValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String _humanizeKey(String key) {
    final withSpaces = key.replaceAll('_', ' ');
    if (withSpaces.isEmpty) return key;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  String _asDateFromAny(dynamic raw) {
    if (raw == null) return '-';

    DateTime? date;
    if (raw is Timestamp) {
      date = raw.toDate();
    } else if (raw is DateTime) {
      date = raw;
    } else if (raw is String) {
      date = DateTime.tryParse(raw);
    }

    if (date == null) return raw.toString();
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  void _showCertificatePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Unable to load certificate image'),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approveTrainer(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify Trainer'),
            content: const Text(
              'This will mark the trainer as verified and allow them to appear as approved in the system.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Verify'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(trainerId);
      final trainerRef = FirebaseFirestore.instance.collection('trainers').doc(trainerId);

      batch.update(userRef, {
        'verified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        trainerRef,
        {
          'verified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trainer verified successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify trainer: $e')),
        );
      }
    }
  }

  Future<void> _revokeVerification(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Revoke Trainer Verification'),
            content: const Text(
              'This will remove the trainer verification badge.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Revoke'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(trainerId);
      final trainerRef = FirebaseFirestore.instance.collection('trainers').doc(trainerId);

      batch.update(userRef, {
        'verified': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(
        trainerRef,
        {
          'verified': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trainer verification revoked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke verification: $e')),
        );
      }
    }
  }
}
