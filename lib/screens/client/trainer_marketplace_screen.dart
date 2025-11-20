import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/trainer_model.dart';
import '../../models/user_model.dart';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Find Trainers',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
      color: Colors.grey[900],
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search trainers...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[850],
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
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedExpertise,
                    isExpanded: true,
                    dropdownColor: Colors.grey[850],
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
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
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  icon: Icon(Icons.sort, color: Colors.grey[400]),
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
          .where('verified', isEqualTo: true)
          .snapshots(),
      builder: (context, trainerSnapshot) {
        if (trainerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (trainerSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading trainers',
              style: TextStyle(color: Colors.grey[400]),
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
                Icon(Icons.person_search, size: 64, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  'No trainers found',
                  style: TextStyle(color: Colors.grey[400], fontSize: 18),
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
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final trainerData = filteredTrainers[index];
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;

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
        final expertise =
            (trainer['expertise'] ?? []).toString().toLowerCase();
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
      color: Colors.grey[900],
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
                    backgroundColor: Colors.grey[800],
                    backgroundImage: avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.people, color: Colors.blue, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$clients clients',
                              style: TextStyle(
                                color: Colors.grey[400],
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
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'per hour',
                        style: TextStyle(
                          color: Colors.grey[500],
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
                  color: Colors.grey[400],
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
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Text(
                        exp,
                        style: const TextStyle(
                          color: Colors.blue,
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
