import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';

class TrainerAvailabilityScreen extends StatefulWidget {
  const TrainerAvailabilityScreen({super.key});

  @override
  State<TrainerAvailabilityScreen> createState() =>
      _TrainerAvailabilityScreenState();
}

class _TrainerAvailabilityScreenState extends State<TrainerAvailabilityScreen> {
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  late Map<String, bool> _availableDays;
  late Map<String, TimeOfDay> _startTimes;
  late Map<String, TimeOfDay> _endTimes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTimes();
    _loadAvailability();
  }

  void _initializeTimes() {
    _availableDays = {
      for (var day in _daysOfWeek) day: true,
    };
    _startTimes = {
      for (var day in _daysOfWeek) day: const TimeOfDay(hour: 9, minute: 0),
    };
    _endTimes = {
      for (var day in _daysOfWeek) day: const TimeOfDay(hour: 17, minute: 0),
    };
  }

  Future<void> _loadAvailability() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) return;

      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerData = trainerSnapshot.docs.first.data();
        final availability =
            trainerData['availability'] as Map<String, dynamic>?;

        if (availability != null) {
          setState(() {
            for (var day in _daysOfWeek) {
              if (availability[day] != null) {
                final dayData = availability[day] as Map<String, dynamic>;
                _availableDays[day] = dayData['available'] ?? true;
                if (dayData['startTime'] != null) {
                  final parts = dayData['startTime'].toString().split(':');
                  _startTimes[day] = TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  );
                }
                if (dayData['endTime'] != null) {
                  final parts = dayData['endTime'].toString().split(':');
                  _endTimes[day] = TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  );
                }
              }
            }
          });
        }
      }
    } catch (e) {
      print('Error loading availability: $e');
    }
  }

  Future<void> _saveAvailability() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final availability = <String, dynamic>{};

      for (var day in _daysOfWeek) {
        availability[day] = {
          'available': _availableDays[day],
          'startTime':
              '${_startTimes[day]!.hour.toString().padLeft(2, '0')}:${_startTimes[day]!.minute.toString().padLeft(2, '0')}',
          'endTime':
              '${_endTimes[day]!.hour.toString().padLeft(2, '0')}:${_endTimes[day]!.minute.toString().padLeft(2, '0')}',
        };
      }

      // Get trainer and update
      final trainerSnapshot = await FirebaseFirestore.instance
          .collection('trainers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (trainerSnapshot.docs.isNotEmpty) {
        final trainerId = trainerSnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('trainers')
            .doc(trainerId)
            .update({'availability': availability});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save availability: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(String day, bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTimes[day]! : _endTimes[day]!,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTimes[day] = picked;
        } else {
          _endTimes[day] = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Set Availability'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Working Hours',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFFFFFF)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your availability for each day of the week',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB0B0B0)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _daysOfWeek.length,
              itemBuilder: (context, index) {
                final day = _daysOfWeek[index];
                return _buildDayAvailability(day);
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isLoading ? 'Saving...' : 'Save Availability',
                isLoading: _isLoading,
                onPressed: _saveAvailability,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayAvailability(String day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF333333)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFFFFFF)
                      : AppColors.textPrimary,
                ),
              ),
              Switch(
                value: _availableDays[day]!,
                onChanged: (value) {
                  setState(() => _availableDays[day] = value);
                },
                activeColor: AppColors.brandGreen,
              ),
            ],
          ),
          if (_availableDays[day]!)
            Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFB0B0B0)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _pickTime(day, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _startTimes[day]!.format(context),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFB0B0B0)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _pickTime(day, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _endTimes[day]!.format(context),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
