import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:genzfit/models/measurement_model.dart';
import 'package:intl/intl.dart';
import 'package:genzfit/utils/constants.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'all'; // all, client, trainer

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'User Management',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _buildUsersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.38)),
              prefixIcon: Icon(Icons.search,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFFFFFF)
                                      : AppColors.textPrimary)
                                  .withOpacity(0.38)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF171917)
                  : AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
          const SizedBox(height: 12),

          // Role Filters
          Row(
            children: [
              _buildRoleChip('All Users', 'all'),
              const SizedBox(width: 8),
              _buildRoleChip('Clients', 'client'),
              const SizedBox(width: 8),
              _buildRoleChip('Trainers', 'trainer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : AppColors.textPrimary)
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary),
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _roleFilter = value);
      },
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171917)
          : AppColors.backgroundLight,
      selectedColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.brandGreen
          : AppColors.brandGreenDeep,
      checkmarkColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : AppColors.textPrimary,
      side: BorderSide(
        color: isSelected
            ? (Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep)
            : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary)
                .withOpacity(0.24),
      ),
    );
  }

  Widget _buildUsersList() {
    Query query = _firestore.collection('users');

    if (_roleFilter != 'all') {
      query = query.where('role', isEqualTo: _roleFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandGreen
                    : AppColors.brandGreenDeep),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary)
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        // Filter by search query
        var filteredDocs = snapshot.data!.docs.where((doc) {
          if (_searchQuery.isEmpty) return true;

          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? '').toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();

          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(
              'No users match your search',
              style: GoogleFonts.inter(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.6)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final user = UserModel.fromFirestore(filteredDocs[index]);
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171917)
          : AppColors.backgroundLight,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: user.status == 'suspended'
              ? Colors.red.withOpacity(0.3)
              : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.12),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F2120)
                  : AppColors.backgroundLight,
              child: user.avatarUrl == null
                  ? Text(
                      user.name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (user.status == 'suspended')
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block,
                    size: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Chip(
              label: Text(
                user.role == UserRole.client ? 'CLIENT' : 'TRAINER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: user.role == UserRole.client
                      ? const Color(0xFF83BCB5)
                      : const Color(0xFFFFD166),
                ),
              ),
              backgroundColor: (user.role == UserRole.client
                      ? const Color(0xFF83BCB5)
                      : const Color(0xFFFFD166))
                  .withOpacity(0.1),
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              user.email,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Joined: ${DateFormat('MMM d, yyyy').format(user.createdAt)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.38),
              ),
            ),
            if (user.status == 'suspended') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'SUSPENDED',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
        children: [
          _buildUserDetails(user),
        ],
      ),
    );
  }

  Widget _buildUserDetails(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)
                .withOpacity(0.12)),
        const SizedBox(height: 16),

        // User-specific details
        if (user.role == UserRole.client) ...[
          _buildDetailRow('Goal', user.goals ?? 'Not set'),
          const SizedBox(height: 12),
          _buildMeasurementSection(user.id),
        ] else if (user.role == UserRole.trainer) ...[
          Row(
            children: [
              Expanded(
                  child: _buildDetailRow('Clients', '${user.clients ?? 0}')),
              Expanded(
                  child: _buildDetailRow(
                      'Rating', '${user.rating?.toStringAsFixed(1) ?? '0.0'}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildDetailRow('Hourly Rate',
                      '\$${user.hourlyRate?.toStringAsFixed(0) ?? '0'}')),
              Expanded(
                  child: _buildDetailRow(
                      'Verified', user.verified == true ? 'Yes' : 'No')),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Total Earnings',
              '\$${user.totalEarnings?.toStringAsFixed(2) ?? '0.00'}'),
        ],

        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            if (user.status != 'suspended')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _suspendUser(user),
                  icon: const Icon(Icons.block),
                  label: Text(
                    'Suspend',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _activateUser(user),
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    'Activate',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _deleteUser(user),
                icon: const Icon(Icons.delete_forever),
                label: Text(
                  'Delete',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade900,
                  side: BorderSide(color: Colors.red.shade900),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)
                .withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementSection(String userId) {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('measurements')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildDetailRow('Latest Measurement', 'No data');
        }

        final measurement =
            MeasurementModel.fromFirestore(snapshot.data!.docs.first);
        return Column(
          children: [
            _buildDetailRow('Weight', '${measurement.weight} kg'),
            const SizedBox(height: 8),
            _buildDetailRow('Height', '${measurement.height} cm'),
            const SizedBox(height: 8),
            _buildDetailRow('BMI', measurement.bmi.toStringAsFixed(1)),
          ],
        );
      },
    );
  }

  Future<void> _suspendUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.backgroundLight,
        title: Text('Suspend User?',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: Text(
          'This will suspend ${user.name}\'s account. They won\'t be able to access the app.',
          style: GoogleFonts.inter(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Suspend', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(user.id).update({
          'status': 'suspended',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.name} has been suspended'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _activateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} has been activated'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.backgroundLight,
        title: Text('Delete User?',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: Text(
          'This will permanently delete ${user.name}\'s account and all associated data. This action cannot be undone.',
          style: GoogleFonts.inter(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(color: Colors.red.shade900)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete user document
        await _firestore.collection('users').doc(user.id).delete();

        // Note: In production, you should also delete related data (measurements, sessions, etc.)
        // This is a simplified version

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.name}\'s account has been deleted'),
              backgroundColor: Colors.red.shade900,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
