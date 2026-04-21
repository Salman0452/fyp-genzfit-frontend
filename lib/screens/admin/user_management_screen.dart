import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/screens/admin/admin_client_insights_screen.dart';
import 'package:genzfit/screens/admin/admin_trainer_insights_screen.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _roleFilterScrollController = ScrollController();
  final ScrollController _tableHorizontalScrollController = ScrollController();
  final Set<String> _updatingUserIds = {};

  String _searchQuery = '';
  String _roleFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    _roleFilterScrollController.dispose();
    _tableHorizontalScrollController.dispose();
    super.dispose();
  }

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
          'Users',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load users: ${snapshot.error}',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: GoogleFonts.inter(color: primaryText),
                    ),
                  );
                }

                final users = snapshot.data!.docs
                    .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
                    .where(_applyFilter)
                    .toList()
                  ..sort((a, b) => _extractDate(b['createdAt'])
                      .compareTo(_extractDate(a['createdAt'])));

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users match your search/filter',
                      style: GoogleFonts.inter(color: primaryText),
                    ),
                  );
                }

                return _buildUsersTable(users);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email, role or UID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          RawScrollbar(
            controller: _roleFilterScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 10,
            radius: const Radius.circular(10),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _roleFilterScrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Role:',
                    style: GoogleFonts.inter(
                      color: secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildRoleChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildRoleChip('Client', 'client'),
                  const SizedBox(width: 8),
                  _buildRoleChip('Trainer', 'trainer'),
                  const SizedBox(width: 8),
                  _buildRoleChip('Admin', 'admin'),
                  const SizedBox(width: 8),
                  _buildRoleChip('Super Admin', 'super_admin'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Password values are never stored in plain text by Firebase Auth. "Not stored" is expected.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, String value) {
    final isSelected = _roleFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = value),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: isSelected
              ? (isDark ? const Color(0xFF1A1A1A) : Colors.white)
              : (isDark ? const Color(0xFFFFFFFF) : AppColors.textPrimary),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : AppColors.surface,
      selectedColor: isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
    );
  }

  Widget _buildUsersTable(List<Map<String, dynamic>> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? const Color(0xFF1A1A1A) : AppColors.surface;
    final secondaryText =
        isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary;

    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: secondaryText.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: RawScrollbar(
            controller: _tableHorizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 10,
            radius: const Radius.circular(10),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _tableHorizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                headingTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                dataTextStyle: GoogleFonts.inter(fontSize: 13),
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Password')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Details')),
                  DataColumn(label: Text('Active')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Account Control')),
                  DataColumn(label: Text('Email Verified')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('UID')),
                ],
                rows: users.map((user) {
                  final role = (user['role'] as String? ?? '-').trim();
                  final roleLower = role.toLowerCase();
                  final status = (user['status'] as String? ?? 'active').trim();
                  final isActive = _isUserActive(user);
                  final createdAt = _extractDate(user['createdAt']);
                  final password = (user['password'] as String?)?.trim();
                  final isClient = roleLower == 'client';
                  final isTrainer = _isTrainerLike(user);
                  final userId = _safeText(user['id']);
                  final isSelf = FirebaseAuth.instance.currentUser?.uid == userId;
                  final isUpdating = _updatingUserIds.contains(userId);

                  return DataRow(
                    cells: [
                      DataCell(Text(_safeText(user['name']) == '-' ? '(no name)' : _safeText(user['name']))),
                      DataCell(Text(_safeText(user['email']))),
                      DataCell(Text(password == null || password.isEmpty ? 'Not stored' : password)),
                      DataCell(Text(role.isEmpty ? '-' : role)),
                      DataCell(
                        (isClient || isTrainer)
                            ? TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => isClient
                                          ? AdminClientInsightsScreen(
                                              clientId: _safeText(user['id']),
                                              clientData: user,
                                            )
                                          : AdminTrainerInsightsScreen(
                                              trainerId: _safeText(user['id']),
                                              trainerUserData: user,
                                            ),
                                    ),
                                  );
                                },
                                child: const Text('View'),
                              )
                            : const Text('-'),
                      ),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isActive ? Colors.green : Colors.red).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(isActive ? 'Yes' : 'No'),
                      )),
                      DataCell(Text(status)),
                      DataCell(
                        isSelf
                            ? Text(
                                'Current account',
                                style: GoogleFonts.inter(fontSize: 12),
                              )
                            : FilledButton.tonalIcon(
                                onPressed: isUpdating
                                    ? null
                                    : () => _toggleAccountStatus(
                                          userId: userId,
                                          currentStatus: status,
                                          currentlyActive: isActive,
                                          userName: _safeText(user['name']),
                                        ),
                                icon: Icon(
                                  isActive ? Icons.block : Icons.check_circle,
                                  size: 16,
                                ),
                                label: Text(
                                  isUpdating
                                      ? 'Updating...'
                                      : (isActive ? 'Disable' : 'Enable'),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: isActive
                                      ? Colors.red.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.18),
                                  foregroundColor: isActive
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                      ),
                      DataCell(Text((user['emailVerified'] == true).toString())),
                      DataCell(Text(createdAt.year < 1971 ? '-' : formatter.format(createdAt))),
                      DataCell(SizedBox(
                        width: 210,
                        child: Text(
                          _safeText(user['id']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                    ],
                  );
                }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _applyFilter(Map<String, dynamic> user) {
    final role = (user['role'] as String? ?? '').toLowerCase().trim();
    if (_roleFilter != 'all' && role != _roleFilter) {
      return false;
    }

    if (_searchQuery.isEmpty) {
      return true;
    }

    final haystack = [
      _safeText(user['name']).toLowerCase(),
      _safeText(user['email']).toLowerCase(),
      _safeText(user['role']).toLowerCase(),
      _safeText(user['id']).toLowerCase(),
      _safeText(user['status']).toLowerCase(),
    ].join(' ');

    return haystack.contains(_searchQuery);
  }

  bool _isUserActive(Map<String, dynamic> user) {
    final status = (user['status'] as String? ?? 'active').toLowerCase();
    final isActiveFlag = user['isActive'] as bool?;

    if (isActiveFlag != null) {
      return isActiveFlag;
    }

    return status != 'suspended' && status != 'inactive' && status != 'disabled';
  }

  DateTime _extractDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _safeText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  bool _isTrainerLike(Map<String, dynamic> user) {
    final role = (user['role'] as String? ?? '').toLowerCase().trim();
    if (role == 'trainer' || role.contains('trainer')) {
      return true;
    }

    final trainerShapeFields = [
      'expertise',
      'hourlyRate',
      'monthlyRate',
      'bio',
      'verified',
      'certifications',
      'videoUrls',
      'clients',
      'totalEarnings',
    ];

    return trainerShapeFields.any(user.containsKey);
  }

  Future<void> _toggleAccountStatus({
    required String userId,
    required String currentStatus,
    required bool currentlyActive,
    required String userName,
  }) async {
    final actionLabel = currentlyActive ? 'disable' : 'enable';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${currentlyActive ? 'Disable' : 'Enable'} Account'),
            content: Text(
              'Are you sure you want to $actionLabel account for ${userName == '-' ? userId : userName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(currentlyActive ? 'Disable' : 'Enable'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _updatingUserIds.add(userId));

    try {
      final now = FieldValue.serverTimestamp();
      final adminUid = FirebaseAuth.instance.currentUser?.uid;

      if (currentlyActive) {
        await _firestore.collection('users').doc(userId).update({
          'status': 'suspended',
          'isActive': false,
          'disabledAt': now,
          'disabledBy': adminUid,
        });
      } else {
        await _firestore.collection('users').doc(userId).update({
          'status': 'active',
          'isActive': true,
          'enabledAt': now,
          'enabledBy': adminUid,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyActive
                ? 'Account disabled successfully.'
                : 'Account enabled successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update account status: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingUserIds.remove(userId));
      }
    }
  }
}
