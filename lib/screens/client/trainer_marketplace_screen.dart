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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'Find Trainers',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFFFFF)
                : AppColors.textPrimary),
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildTrainerList()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search trainers...',
              hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary),
              prefixIcon: Icon(Icons.search,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B0B0)
                      : AppColors.textSecondary),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A1A)
                  : AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
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
          const SizedBox(height: 12),
          // Filters
          Row(
            children: [
              // Expertise filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.charcoal
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedExpertise,
                    isExpanded: true,
                    dropdownColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.charcoal
                            : AppColors.surfaceVariant,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textOnBrand
                          : AppColors.textPrimary,
                    ),
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                    items: _expertiseOptions.map((expertise) {
                      return DropdownMenuItem(
                        value: expertise,
                        child: Text(expertise),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedExpertise = value!);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort by
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.charcoal
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.charcoal
                      : AppColors.surfaceVariant,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textOnBrand
                        : AppColors.textPrimary,
                  ),
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.sort,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondary
                        : AppColors.textSecondary,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rating', child: Text('Rating')),
                    DropdownMenuItem(value: 'price', child: Text('Price')),
                    DropdownMenuItem(value: 'clients', child: Text('Clients')),
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

                return _buildTrainerCard(trainerData, userData);
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
    final name = userData['name'] ?? 'Trainer';
    final avatarUrl = userData['avatarUrl'] ?? '';
    final bio = trainerData['bio'] ?? 'No bio available';
    final rating = (trainerData['rating'] ?? 0.0).toDouble();
    final hourlyRate = (trainerData['hourlyRate'] ?? 0.0).toDouble();
    final clients = trainerData['clients'] ?? 0;
    final expertise = List<String>.from(trainerData['expertise'] ?? []);

    return Card(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A1A)
          : AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.textSecondary,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textOnBrand,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textOnBrand
                                    : AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: AppColors.brandGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.people,
                              color: AppColors.brandBlue,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$clients clients',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${hourlyRate.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.brandBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'per hour',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (expertise.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expertise.take(3).map((exp) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.brandBlue,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        exp,
                        style: const TextStyle(
                          color: AppColors.brandBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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
