import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../routes/app_routes.dart';

class TrainersListScreen extends StatefulWidget {
  const TrainersListScreen({super.key});

  @override
  State<TrainersListScreen> createState() => _TrainersListScreenState();
}

class _TrainersListScreenState extends State<TrainersListScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Strength',
    'Cardio',
    'Yoga',
    'HIIT',
    'Nutrition',
  ];

  // Mock data - Replace with actual API call
  final List<Map<String, dynamic>> _trainers = [
    {
      'id': '1',
      'name': 'Sarah Johnson',
      'specialization': 'Strength & Conditioning',
      'experience': '8 years',
      'rating': 4.9,
      'reviewCount': 127,
      'price': '\$50/session',
      'image': null,
      'certifications': ['NASM-CPT', 'CrossFit Level 2'],
      'availableSlots': 12,
    },
    {
      'id': '2',
      'name': 'Mike Chen',
      'specialization': 'Weight Loss & Cardio',
      'experience': '5 years',
      'rating': 4.8,
      'reviewCount': 89,
      'price': '\$45/session',
      'image': null,
      'certifications': ['ACE-CPT', 'Nutrition Coach'],
      'availableSlots': 8,
    },
    {
      'id': '3',
      'name': 'Emily Rodriguez',
      'specialization': 'Yoga & Flexibility',
      'experience': '10 years',
      'rating': 5.0,
      'reviewCount': 203,
      'price': '\$40/session',
      'image': null,
      'certifications': ['RYT-500', 'Pilates Instructor'],
      'availableSlots': 15,
    },
    {
      'id': '4',
      'name': 'David Kim',
      'specialization': 'HIIT & Athletic Performance',
      'experience': '6 years',
      'rating': 4.7,
      'reviewCount': 156,
      'price': '\$55/session',
      'image': null,
      'certifications': ['CSCS', 'USA Track & Field'],
      'availableSlots': 5,
    },
    {
      'id': '5',
      'name': 'Lisa Martinez',
      'specialization': 'Nutrition & Wellness',
      'experience': '12 years',
      'rating': 4.9,
      'reviewCount': 178,
      'price': '\$60/session',
      'image': null,
      'certifications': ['RD', 'NASM-CPT', 'Precision Nutrition'],
      'availableSlots': 10,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientDecoration(context),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Trainers',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_trainers.length} certified trainers available',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Filter Chips
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final filter = _filterOptions[index];
                    final isSelected = _selectedFilter == filter;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        selectedColor: Colors.white.withValues(alpha: 0.3),
                        labelStyle: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Trainers List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _trainers.length,
                  itemBuilder: (context, index) {
                    final trainer = _trainers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildTrainerCard(context, trainer, isDarkMode),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerCard(BuildContext context, Map<String, dynamic> trainer, bool isDarkMode) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.trainerProfile,
          arguments: trainer,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trainer Avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Trainer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trainer['name'],
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.verified,
                            size: 20,
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trainer['specialization'],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amberAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${trainer['rating']}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            ' (${trainer['reviewCount']} reviews)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  Icons.work_outline,
                  trainer['experience'],
                  'Experience',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildStatItem(
                  Icons.attach_money,
                  trainer['price'],
                  'Per Session',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildStatItem(
                  Icons.calendar_today,
                  '${trainer['availableSlots']} slots',
                  'Available',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.trainerProfile,
                    arguments: trainer,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF37CDFA),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'View Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
