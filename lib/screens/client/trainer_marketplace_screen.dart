import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:genzfit/utils/constants.dart';
import '../shared/loading_widget.dart';
import 'trainer_detail_screen.dart';

class TrainerMarketplaceScreen extends StatefulWidget {
  const TrainerMarketplaceScreen({super.key});

  @override
  State<TrainerMarketplaceScreen> createState() =>
      _TrainerMarketplaceScreenState();
}

class _TrainerMarketplaceScreenState extends State<TrainerMarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedExpertise = 'All';
  String _sortBy = 'rating'; // rating, price, clients
  bool _showOnlyVerified = false;

  final List<String> _expertiseOptions = [
    'All',
    'Weight Loss',
    'Muscle Gain',
    'Yoga',
    'Cardio',
    'Strength Training',
    'CrossFit',
    'Nutrition',
    'Rehabilitation',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              'Find Trainers',
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
              'Book your ideal fitness trainer',
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
        iconTheme: IconThemeData(
          color: accentColor,
          size: 20,
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(isDarkMode, accentColor),
          Expanded(child: _buildTrainerList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDarkMode, Color accentColor) {
    return Container(
      color: isDarkMode ? const Color(0xFF1A1A1A) : AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Modern search bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
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
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search trainers by name or expertise...',
                hintStyle: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: accentColor,
                  size: 18,
                ),
                filled: true,
                fillColor:
                    isDarkMode ? const Color(0xFF262626) : AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  borderSide: BorderSide(
                    color: accentColor.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  borderSide: BorderSide(
                    color: accentColor.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  borderSide: BorderSide(
                    color: accentColor,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          const SizedBox(height: 14),
          // Verified filter chip
          Row(
            children: [
              FilterChip(
                label: const Text('Verified Only'),
                selected: _showOnlyVerified,
                onSelected: (selected) {
                  setState(() => _showOnlyVerified = selected);
                },
                backgroundColor:
                    isDarkMode ? const Color(0xFF262626) : AppColors.surface,
                selectedColor: accentColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: _showOnlyVerified ? accentColor : null,
                  fontWeight:
                      _showOnlyVerified ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: _showOnlyVerified
                      ? accentColor
                      : accentColor.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 12),
          // Filters row
          Row(
            children: [
              // Expertise filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF262626)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withOpacity(0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.15)
                            : Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: _selectedExpertise,
                    isExpanded: true,
                    dropdownColor: isDarkMode
                        ? const Color(0xFF262626)
                        : AppColors.surface,
                    style: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFFFFFFFF)
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.expand_more_rounded,
                      color: accentColor,
                      size: 18,
                    ),
                    items: _expertiseOptions.map((expertise) {
                      return DropdownMenuItem(
                        value: expertise,
                        child: Row(
                          children: [
                            Icon(
                              expertise == 'All'
                                  ? Icons.apps_rounded
                                  : Icons.check_circle_rounded,
                              size: 14,
                              color: accentColor.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Text(expertise),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedExpertise = value!);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Sort by filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? const Color(0xFF262626) : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.15)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor:
                      isDarkMode ? const Color(0xFF262626) : AppColors.surface,
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFFFFFFFF)
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.expand_more_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'rating',
                      child: Row(
                        children: [
                          Icon(Icons.star_rounded, size: 14),
                          SizedBox(width: 8),
                          Text('Rating'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'price',
                      child: Row(
                        children: [
                          Icon(Icons.trending_down_rounded, size: 14),
                          SizedBox(width: 8),
                          Text('Price'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'clients',
                      child: Row(
                        children: [
                          Icon(Icons.people_rounded, size: 14),
                          SizedBox(width: 8),
                          Text('Clients'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _sortBy = value!);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trainers')
          // Temporarily removed verified filter for testing
          // .where('verified', isEqualTo: true)
          .snapshots(),
      builder: (context, trainerSnapshot) {
        if (trainerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (trainerSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading trainers',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        var trainers = trainerSnapshot.data?.docs ?? [];

        // Filter and sort trainers
        var filteredTrainers = _filterAndSortTrainers(trainers);

        if (filteredTrainers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_search,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No trainers found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTrainers.length,
          itemBuilder: (context, index) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(filteredTrainers[index]['userId'])
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData ||
                    userSnapshot.data?.data() == null) {
                  return const SizedBox.shrink();
                }

                final trainerData = filteredTrainers[index];
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null) {
                  return const SizedBox.shrink();
                }

                // Add verified status from userData to trainerData for filtering
                final trainerDataWithVerified = {
                  ...trainerData,
                  'verified': userData['verified'] ?? false,
                };

                // Check if should be displayed based on verified filter
                if (_showOnlyVerified &&
                    trainerDataWithVerified['verified'] != true) {
                  return const SizedBox.shrink();
                }

                return _buildTrainerCard(trainerDataWithVerified, userData);
              },
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterAndSortTrainers(
      List<QueryDocumentSnapshot> trainers) {
    var trainerList = trainers.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id};
    }).toList();

    // Apply expertise filter
    if (_selectedExpertise != 'All') {
      trainerList = trainerList.where((trainer) {
        final expertise = List<String>.from(trainer['expertise'] ?? []);
        return expertise.contains(_selectedExpertise);
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      trainerList = trainerList.where((trainer) {
        final bio = (trainer['bio'] ?? '').toString().toLowerCase();
        final expertise = (trainer['expertise'] ?? []).toString().toLowerCase();
        return bio.contains(_searchQuery) || expertise.contains(_searchQuery);
      }).toList();
    }

    // Sort trainers
    trainerList.sort((a, b) {
      switch (_sortBy) {
        case 'rating':
          return (b['rating'] ?? 0.0).compareTo(a['rating'] ?? 0.0);
        case 'price':
          return (a['hourlyRate'] ?? 0.0).compareTo(b['hourlyRate'] ?? 0.0);
        case 'clients':
          return (b['clients'] ?? 0).compareTo(a['clients'] ?? 0);
        default:
          return 0;
      }
    });

    return trainerList;
  }

  Widget _buildTrainerCard(
    Map<String, dynamic> trainerData,
    Map<String, dynamic> userData,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDarkMode ? AppColors.brandGreen : AppColors.brandGreenDeep;

    final name = userData['name'] ?? 'Trainer';
    final avatarUrl = userData['avatarUrl'] ?? '';
    final bio = trainerData['bio'] ?? 'No bio available';
    final rating = (trainerData['rating'] ?? 0.0).toDouble();
    final monthlyRate = (trainerData['monthlyRate'] ?? 0.0).toDouble();
    final clients = trainerData['clients'] ?? 0;
    final expertise = List<String>.from(trainerData['expertise'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF262626) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: accentColor.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrainerDetailScreen(
                trainerId: trainerData['id'],
                userId: trainerData['userId'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with trainer info and price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                color: accentColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: accentColor,
                                  size: 28,
                                ),
                              ),
                            )
                          : Container(
                              color: accentColor.withOpacity(0.1),
                              child: Center(
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode
                                      ? const Color(0xFFFFFFFF)
                                      : AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trainerData['verified'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.brandGreenDeep,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.brandGreenDeep
                                          .withOpacity(0.25),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: accentColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? const Color(0xFFFFFFFF)
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 14,
                              color: accentColor.withOpacity(0.2),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.people_rounded,
                              color: AppColors.brandBlue,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$clients',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                  // Price badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PKR ${monthlyRate.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'per month',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? const Color(0xFFB0B0B0)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bio section
              Text(
                bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? const Color(0xFFC0C0C0)
                      : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              // Expertise badges
              if (expertise.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expertise.take(3).map((exp) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.brandBlue.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_rounded,
                            color: AppColors.brandBlue,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            exp,
                            style: const TextStyle(
                              color: AppColors.brandBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
