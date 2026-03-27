import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:genzfit/models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:genzfit/utils/constants.dart';

class TrainerVerificationScreen extends StatefulWidget {
  const TrainerVerificationScreen({super.key});

  @override
  State<TrainerVerificationScreen> createState() =>
      _TrainerVerificationScreenState();
}

class _TrainerVerificationScreenState extends State<TrainerVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterStatus = 'pending'; // pending, verified, all

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trainer Verification',
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
          _buildFilterChips(),
          Expanded(
            child: _buildTrainersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          _buildFilterChip('Pending', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('Verified', 'verified'),
          const SizedBox(width: 8),
          _buildFilterChip('All', 'all'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
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
        setState(() => _filterStatus = value);
      },
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171917)
          : AppColors.surface,
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

  Widget _buildTrainersList() {
    Query query =
        _firestore.collection('users').where('role', isEqualTo: 'trainer');

    if (_filterStatus == 'pending') {
      query = query.where('verified', isEqualTo: false);
    } else if (_filterStatus == 'verified') {
      query = query.where('verified', isEqualTo: true);
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
                  Icons.verified_user_outlined,
                  size: 80,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary)
                      .withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No trainers found',
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final trainerDoc = snapshot.data!.docs[index];
            final trainer = UserModel.fromFirestore(trainerDoc);
            return _buildTrainerCard(trainer);
          },
        );
      },
    );
  }

  Widget _buildTrainerCard(UserModel trainer) {
    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF171917)
          : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: trainer.verified == true
              ? (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.brandGreen
                      : AppColors.brandGreenDeep)
                  .withOpacity(0.3)
              : const Color(0xFFFFD166).withOpacity(0.3),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        childrenPadding: const EdgeInsets.all(20),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: trainer.avatarUrl != null
                  ? NetworkImage(trainer.avatarUrl!)
                  : null,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F2120)
                  : AppColors.surface,
              child: trainer.avatarUrl == null
                  ? Text(
                      trainer.name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            if (trainer.verified == true)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
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
                trainer.name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (trainer.verified == true)
              Chip(
                label: Text(
                  'VERIFIED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7FFA88),
                  ),
                ),
                backgroundColor: const Color(0xFF7FFA88).withOpacity(0.1),
                side:
                    BorderSide(color: const Color(0xFF7FFA88).withOpacity(0.3)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            else
              Chip(
                label: Text(
                  'PENDING',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD166),
                  ),
                ),
                backgroundColor: const Color(0xFFFFD166).withOpacity(0.1),
                side:
                    BorderSide(color: const Color(0xFFFFD166).withOpacity(0.3)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              trainer.email,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Joined: ${DateFormat('MMM d, yyyy').format(trainer.createdAt)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.38),
              ),
            ),
            if (trainer.expertise != null && trainer.expertise!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: trainer.expertise!.take(3).map((exp) {
                  return Chip(
                    label: Text(
                      exp,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep,
                      ),
                    ),
                    backgroundColor:
                        (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.brandGreen
                                : AppColors.brandGreenDeep)
                            .withOpacity(0.1),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        children: [
          _buildTrainerDetails(trainer),
        ],
      ),
    );
  }

  Widget _buildTrainerDetails(UserModel trainer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)
                .withOpacity(0.12)),
        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                Icons.people,
                'Clients',
                '${trainer.clients ?? 0}',
              ),
            ),
            Expanded(
              child: _buildStatItem(
                Icons.star,
                'Rating',
                '${trainer.rating?.toStringAsFixed(1) ?? '0.0'}',
              ),
            ),
            Expanded(
              child: _buildStatItem(
                Icons.attach_money,
                'Rate/hr',
                '\$${trainer.hourlyRate?.toStringAsFixed(0) ?? '0'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Pricing Information
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F2120)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary)
                  .withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pricing',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hourly Rate',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFFFFFFF)
                                        : AppColors.textPrimary)
                                    .withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PKR ${trainer.hourlyRate?.toStringAsFixed(0) ?? '0'}/hr',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.brandGreen
                                    : AppColors.brandGreenDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trainer.monthlyRate != null && trainer.monthlyRate! > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Rate',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFFFFFFF)
                                      : AppColors.textPrimary)
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PKR ${trainer.monthlyRate?.toStringAsFixed(0) ?? '0'}/mo',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.brandGreen
                                  : AppColors.brandGreenDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bio/About
        if (trainer.bio != null && trainer.bio!.isNotEmpty) ...[
          Text(
            'About',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F2120)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)
                    .withOpacity(0.1),
              ),
            ),
            child: Text(
              trainer.bio!,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Expertise
        if (trainer.expertise != null && trainer.expertise!.isNotEmpty) ...[
          Text(
            'Expertise',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: trainer.expertise!.map((exp) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.brandGreen
                          : AppColors.brandGreenDeep)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep)
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  exp,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Certifications
        if (trainer.certifications != null &&
            trainer.certifications!.isNotEmpty) ...[
          Text(
            'Certifications',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: trainer.certifications!.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showImageDialog(trainer.certifications![index]),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFFFFFF)
                                      : AppColors.textPrimary)
                                  .withOpacity(0.24)),
                      image: DecorationImage(
                        image: NetworkImage(trainer.certifications![index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.zoom_in,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFFFFFF)
                            : AppColors.textPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Videos
        if (trainer.videoUrls != null && trainer.videoUrls!.isNotEmpty) ...[
          Text(
            'Video Introductions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFFFFFF)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...trainer.videoUrls!.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _showVideoDialog(url),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1F2120)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.brandGreen
                                    : AppColors.brandGreenDeep),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Video Introduction',
                            style: GoogleFonts.inter(
                                color: (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFFFFFFF)
                                        : AppColors.textPrimary)
                                    .withOpacity(0.7)),
                          ),
                        ),
                        Icon(Icons.open_in_new,
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFFFFFFF)
                                        : AppColors.textPrimary)
                                    .withOpacity(0.38),
                            size: 16),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 20),
        ],

        // Action Buttons
        if (trainer.verified != true) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveTrainer(trainer),
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    'Approve',
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
                  onPressed: () => _rejectTrainer(trainer),
                  icon: const Icon(Icons.cancel),
                  label: Text(
                    'Reject',
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
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _revokeVerification(trainer),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(
                    'Revoke Verification',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD166),
                    side: const BorderSide(color: Color(0xFFFFD166)),
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
                  onPressed: () => _suspendTrainer(trainer),
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
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.brandGreen
                : AppColors.brandGreenDeep,
            size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)
                .withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF171917)
                  : AppColors.surface,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Certificate', style: GoogleFonts.poppins()),
            ),
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.brandGreen
                            : AppColors.brandGreenDeep),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoDialog(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        title: Text('Video Link',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: SelectableText(
          videoUrl,
          style: GoogleFonts.inter(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandGreen
                  : AppColors.brandGreenDeep),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _approveTrainer(UserModel trainer) async {
    try {
      await _firestore.collection('users').doc(trainer.id).update({
        'verified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trainer.name} has been approved!'),
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

  Future<void> _rejectTrainer(UserModel trainer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        title: Text('Reject Trainer?',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: Text(
          'This will keep ${trainer.name} unverified. They can resubmit later.',
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
            child: Text('Reject', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trainer.name} verification rejected'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _revokeVerification(UserModel trainer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        title: Text('Revoke Verification?',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: Text(
          'This will remove verification status from ${trainer.name}.',
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
            child: Text('Revoke',
                style: GoogleFonts.inter(color: const Color(0xFFFFD166))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(trainer.id).update({
          'verified': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification revoked for ${trainer.name}'),
              backgroundColor: const Color(0xFFFFD166),
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

  Future<void> _suspendTrainer(UserModel trainer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF171917)
            : AppColors.surface,
        title: Text('Suspend Trainer?',
            style: GoogleFonts.poppins(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary)),
        content: Text(
          'This will suspend ${trainer.name}\'s account. They won\'t be able to accept new clients.',
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
        await _firestore.collection('users').doc(trainer.id).update({
          'status': 'suspended',
          'verified': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${trainer.name} has been suspended'),
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
}
