import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminClientInsightsScreen extends StatelessWidget {
  final String clientId;
  final Map<String, dynamic> clientData;

  const AdminClientInsightsScreen({
    super.key,
    required this.clientId,
    required this.clientData,
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
          'Client Details',
          style: GoogleFonts.poppins(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildClientHeader(context),
          const SizedBox(height: 16),
          _buildSubscriptionSection(context),
          const SizedBox(height: 16),
          _buildPreferencesSection(context),
          const SizedBox(height: 16),
          _buildMeasurementsSection(context),
        ],
      ),
    );
  }

  Widget _buildClientHeader(BuildContext context) {
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
            (clientData['name'] as String?)?.trim().isNotEmpty == true
                ? clientData['name'] as String
                : '(Unnamed Client)',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _safeText(clientData['email']),
            style: GoogleFonts.inter(color: secondaryText),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Goal: ${_safeText(clientData['goals'])}'),
              _chip(context, 'Skin Tone: ${_safeText(clientData['skinTone'])}'),
              _chip(context, 'Status: ${_safeText(clientData['status'])}'),
              _chip(context, 'UID: $clientId'),
            ],
          ),
        ],
      ),
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
                .doc(clientId)
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

              final storedPrefs =
                  snapshot.data?.data() as Map<String, dynamic>?;
              final userInlinePrefs =
                  clientData['preferences'] is Map<String, dynamic>
                      ? clientData['preferences'] as Map<String, dynamic>
                      : <String, dynamic>{};
              final merged = <String, dynamic>{
                ...userInlinePrefs,
                ...?storedPrefs,
              };

              if (merged.isEmpty) {
                return Text(
                  'No preferences found for this client.',
                  style: GoogleFonts.inter(color: secondaryText),
                );
              }

              return _buildGroupedPreferences(context, merged);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(BuildContext context) {
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
            'Subscription & Chatbot Usage',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_subscriptions')
                .where('userId', isEqualTo: clientId)
                .snapshots(),
            builder: (context, subscriptionSnapshot) {
              if (subscriptionSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }

              if (subscriptionSnapshot.hasError) {
                return Text(
                  'Failed to load subscription details: ${subscriptionSnapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red),
                );
              }

              final subscriptionDocs =
                  subscriptionSnapshot.data?.docs ?? const [];
              if (subscriptionDocs.isEmpty) {
                return Text(
                  'No subscription records found for this user.',
                  style: GoogleFonts.inter(color: secondaryText),
                );
              }

              final subscriptions = subscriptionDocs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList()
                ..sort((a, b) => _asDate(_subscriptionTimelineDate(b))
                    .compareTo(_asDate(_subscriptionTimelineDate(a))));

              final latest = subscriptions.first;
              final status = _safeText(latest['status']).toLowerCase();
              final planId = _safeText(latest['planId']) == '-'
                  ? ''
                  : _safeText(latest['planId']);
              final planName = _safeText(latest['planName']) == '-'
                  ? (planId.isEmpty ? 'Unknown Plan' : planId)
                  : _safeText(latest['planName']);

              final activatedAt = latest['approvedDate'] ?? latest['startDate'];
              final endAt = latest['endDate'];
              final requestAt = latest['startDate'];

              if (planId.isEmpty) {
                return _buildSubscriptionUsageContent(
                  context,
                  planName: planName,
                  status: status,
                  activatedAt: activatedAt,
                  endAt: endAt,
                  requestAt: requestAt,
                  dailyMessageLimit: null,
                );
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('plans')
                    .doc(planId)
                    .get(),
                builder: (context, planSnapshot) {
                  final planData =
                      planSnapshot.data?.data() as Map<String, dynamic>?;
                  final dailyLimit =
                      (latest['dailyMessageLimit'] as num?)?.toInt() ??
                          (planData?['dailyMessageLimit'] as num?)?.toInt();

                  return _buildSubscriptionUsageContent(
                    context,
                    planName: planName,
                    status: status,
                    activatedAt: activatedAt,
                    endAt: endAt,
                    requestAt: requestAt,
                    dailyMessageLimit: dailyLimit,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionUsageContent(
    BuildContext context, {
    required String planName,
    required String status,
    required dynamic activatedAt,
    required dynamic endAt,
    required dynamic requestAt,
    required int? dailyMessageLimit,
  }) {
    final secondaryText = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB0B0B0)
        : AppColors.textSecondary;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chatbot_usage')
          .where('userId', isEqualTo: clientId)
          .snapshots(),
      builder: (context, usageSnapshot) {
        int messagesUsedToday = 0;

        if (usageSnapshot.hasData) {
          final docs = usageSnapshot.data!.docs;
          final now = DateTime.now();

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final usageDate = _asDate(data['date']);
            if (_isSameDay(usageDate, now)) {
              messagesUsedToday = (data['messageCount'] as num?)?.toInt() ?? 0;
              break;
            }
          }
        }

        final messagesLeft = dailyMessageLimit == null
            ? null
            : (dailyMessageLimit - messagesUsedToday)
                .clamp(0, dailyMessageLimit);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'Plan: $planName'),
                _chip(context, 'Status: ${_formatStatus(status)}'),
                if (dailyMessageLimit != null)
                  _chip(context, 'Daily Limit: $dailyMessageLimit messages'),
              ],
            ),
            const SizedBox(height: 12),
            _buildKeyValue(
                context, 'Activated On', _asDateFromAny(activatedAt)),
            _buildKeyValue(context, 'Ends On', _asDateFromAny(endAt)),
            _buildKeyValue(context, 'Requested On', _asDateFromAny(requestAt)),
            _buildKeyValue(context, 'Messages Used Today', messagesUsedToday),
            _buildKeyValue(
              context,
              'Messages Left Today',
              messagesLeft == null
                  ? 'Unknown (plan limit unavailable)'
                  : messagesLeft,
            ),
            if (usageSnapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Usage stats could not be fully loaded: ${usageSnapshot.error}',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            if (status == 'pending' || status == 'rejected')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  status == 'pending'
                      ? 'Subscription is pending admin approval.'
                      : 'Subscription request was rejected.',
                  style: GoogleFonts.inter(
                    color: secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMeasurementsSection(BuildContext context) {
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
            'Measurements',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('measurements')
                .where('userId', isEqualTo: clientId)
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
                  'Failed to load measurements: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text(
                  'No measurements found for this client.',
                  style: GoogleFonts.inter(color: secondaryText),
                );
              }

              final docs = [...snapshot.data!.docs]..sort((a, b) =>
                  _asDate((b.data() as Map<String, dynamic>)['date']).compareTo(
                      _asDate((a.data() as Map<String, dynamic>)['date'])));

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = _asDate(data['date']);
                  final height = (data['height'] as num?)?.toDouble();
                  final weight = (data['weight'] as num?)?.toDouble();
                  final bmi = (height != null && height > 0 && weight != null)
                      ? weight / ((height / 100) * (height / 100))
                      : null;
                  final estimated = data['estimatedMeasurements'] is Map
                      ? Map<String, dynamic>.from(
                          data['estimatedMeasurements'] as Map)
                      : <String, dynamic>{};
                  final photos = data['photoUrls'] is List
                      ? List<dynamic>.from(data['photoUrls'] as List)
                      : const [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: secondaryText.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(date),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      subtitle: Text(
                        'H: ${_numText(height)} cm  W: ${_numText(weight)} kg  BMI: ${_numText(bmi)}',
                        style: GoogleFonts.inter(color: secondaryText),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Estimated Measurements',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (estimated.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No estimated measurements saved.',
                              style: GoogleFonts.inter(color: secondaryText),
                            ),
                          )
                        else
                          ...estimated.entries.map(
                            (entry) =>
                                _buildKeyValue(context, entry.key, entry.value),
                          ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Photos: ${photos.length}',
                            style: GoogleFonts.inter(color: secondaryText),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
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
              _humanizeKey(key),
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

  Widget _buildGroupedPreferences(
      BuildContext context, Map<String, dynamic> prefs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    final groups = <String, List<String>>{
      'Workout': [
        'goal',
        'fitness_level',
        'workout_location',
        'workout_days_per_week',
        'workout_duration_minutes',
        'available_equipment',
        'disliked_exercises',
        'injury_limitations',
      ],
      'Nutrition': [
        'cuisine_preference',
        'meals_per_day',
        'dietary_restrictions',
        'food_allergies',
        'disliked_foods',
      ],
      'Body': [
        'age',
        'gender',
        'height_cm',
        'weight_kg',
      ],
      'Health': [
        'health_conditions',
      ],
    };

    final knownKeys = groups.values.expand((keys) => keys).toSet();
    final otherEntries = prefs.entries
        .where((entry) => !knownKeys.contains(entry.key))
        .where((entry) => _hasDisplayableValue(entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final sections = <Widget>[];

    for (final group in groups.entries) {
      final presentKeys = group.value
          .where((key) => prefs.containsKey(key))
          .where((key) => _hasDisplayableValue(prefs[key]))
          .toList();

      if (presentKeys.isEmpty) {
        continue;
      }

      sections.add(
        _buildPreferenceGroupTile(
          context,
          title: group.key,
          entries: presentKeys
              .map((key) => MapEntry<String, dynamic>(key, prefs[key]))
              .toList(),
        ),
      );

      sections.add(const SizedBox(height: 8));
    }

    if (otherEntries.isNotEmpty) {
      sections.add(
        _buildPreferenceGroupTile(
          context,
          title: 'Other',
          entries: otherEntries,
        ),
      );
    }

    if (sections.isEmpty) {
      return Text(
        'No preferences found for this client.',
        style: GoogleFonts.inter(
          color: secondaryText,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildPreferenceGroupTile(
    BuildContext context, {
    required String title,
    required List<MapEntry<String, dynamic>> entries,
  }) {
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
          '${entries.length} item${entries.length == 1 ? '' : 's'}',
          style: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 12,
          ),
        ),
        children: entries
            .map((entry) => _buildKeyValue(context, entry.key, entry.value))
            .toList(),
      ),
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

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _numText(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return '-';
    }
    return value.toStringAsFixed(1);
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  dynamic _subscriptionTimelineDate(Map<String, dynamic> subscription) {
    return subscription['approvedDate'] ??
        subscription['startDate'] ??
        subscription['endDate'];
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
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

  String _formatStatus(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    if (normalized.isEmpty || normalized == '-') return '-';
    return normalized[0].toUpperCase() + normalized.substring(1);
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
}
