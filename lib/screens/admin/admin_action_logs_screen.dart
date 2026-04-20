import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminActionLogsScreen extends StatefulWidget {
  const AdminActionLogsScreen({super.key});

  @override
  State<AdminActionLogsScreen> createState() => _AdminActionLogsScreenState();
}

class _AdminActionLogsScreenState extends State<AdminActionLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _actionTypeFilter = 'all';
  String _searchQuery = '';

  static const List<String> _supportedActionTypes = [
    'all',
    'payment_approved',
    'payment_rejected',
    'withdrawal_approved',
    'withdrawal_rejected',
    'withdrawal_processing',
    'withdrawal_completed',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E0E) : AppColors.background;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final primaryText = isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;
    final brandGreen = isDark ? AppColors.brandGreen : AppColors.brandGreenDeep;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'Admin Action Logs',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                  style: TextStyle(color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'Search by admin ID, entity ID, or action',
                    hintStyle: TextStyle(color: secondaryText),
                    prefixIcon: Icon(Icons.search, color: brandGreen),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF101010) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Action Type',
                      style: GoogleFonts.inter(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF101010)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _actionTypeFilter,
                            dropdownColor:
                                isDark ? const Color(0xFF222222) : Colors.white,
                            isExpanded: true,
                            style: TextStyle(color: primaryText),
                            items: _supportedActionTypes
                                .map(
                                  (type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      _prettifyActionType(type),
                                      style: GoogleFonts.inter(color: primaryText),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _actionTypeFilter = value);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('admin_action_logs')
                  .orderBy('createdAt', descending: true)
                  .limit(250)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load logs: ${snapshot.error}',
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final actionType = (data['actionType'] as String? ?? '').toLowerCase();
                  final adminId = (data['adminId'] as String? ?? '').toLowerCase();
                  final entityId = (data['entityId'] as String? ?? '').toLowerCase();

                  final typeMatches = _actionTypeFilter == 'all' ||
                      actionType == _actionTypeFilter.toLowerCase();

                  if (!typeMatches) return false;
                  if (_searchQuery.isEmpty) return true;

                  return actionType.contains(_searchQuery) ||
                      adminId.contains(_searchQuery) ||
                      entityId.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No audit logs match your filters',
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildLogCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final primaryText = isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    final data = doc.data();
    final actionType = data['actionType'] as String? ?? 'unknown';
    final entityType = data['entityType'] as String? ?? 'entity';
    final entityId = data['entityId'] as String? ?? '';
    final adminId = data['adminId'] as String? ?? '';
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final chipColor = _actionColor(actionType);
    final shortEntity = entityId.length > 10 ? '${entityId.substring(0, 10)}...' : entityId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _prettifyActionType(actionType),
                  style: GoogleFonts.inter(
                    color: chipColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                createdAt == null
                    ? 'Unknown time'
                    : DateFormat('MMM dd, yyyy • HH:mm:ss').format(createdAt),
                style: GoogleFonts.inter(
                  color: secondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$entityType • $shortEntity',
            style: GoogleFonts.poppins(
              color: primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Admin: $adminId',
            style: GoogleFonts.inter(color: secondaryText),
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _metadataSummary(metadata),
              style: GoogleFonts.inter(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _prettifyActionType(String value) {
    if (value == 'all') return 'All Actions';

    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _metadataSummary(Map<String, dynamic> metadata) {
    final entries = metadata.entries.take(4).map((entry) {
      return '${entry.key}: ${entry.value}';
    }).join(' • ');

    return entries;
  }

  Color _actionColor(String actionType) {
    if (actionType.contains('approved') || actionType.contains('completed')) {
      return AppColors.success;
    }
    if (actionType.contains('rejected')) {
      return AppColors.error;
    }
    if (actionType.contains('processing')) {
      return Colors.cyan;
    }

    return AppColors.brandBlue;
  }
}