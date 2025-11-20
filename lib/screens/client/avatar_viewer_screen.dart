import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/avatar_model.dart';
import '../../models/measurement_model.dart';
import '../../providers/auth_provider.dart';

class AvatarViewerScreen extends StatefulWidget {
  const AvatarViewerScreen({super.key});

  @override
  State<AvatarViewerScreen> createState() => _AvatarViewerScreenState();
}

class _AvatarViewerScreenState extends State<AvatarViewerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Avatar3D? _avatar;
  MeasurementModel? _latestMeasurement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) return;

      // Load latest measurement
      final measurementSnapshot = await _firestore
          .collection('measurements')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (measurementSnapshot.docs.isNotEmpty) {
        _latestMeasurement = MeasurementModel.fromFirestore(measurementSnapshot.docs.first);
      }

      // Load or create avatar
      final avatarSnapshot = await _firestore
          .collection('avatars')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (avatarSnapshot.docs.isNotEmpty) {
        _avatar = Avatar3D.fromFirestore(avatarSnapshot.docs.first);
      } else if (_latestMeasurement != null) {
        // Create new avatar from measurements
        await _createAvatar(userId, _latestMeasurement!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading avatar data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createAvatar(String userId, MeasurementModel measurement) async {
    try {
      final avatarData = {
        'userId': userId,
        'modelUrl': _getDefaultModelUrl(),
        'measurements': measurement.estimatedMeasurements ?? {},
        'createdAt': Timestamp.now(),
      };

      final doc = await _firestore.collection('avatars').add(avatarData);
      final avatarDoc = await doc.get();
      _avatar = Avatar3D.fromFirestore(avatarDoc);
    } catch (e) {
      print('Error creating avatar: $e');
    }
  }

  String _getDefaultModelUrl() {
    // For now, use a placeholder 3D model URL
    // In production, this would be dynamically generated based on measurements
    return 'https://modelviewer.dev/shared-assets/models/Astronaut.glb';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '3D Body Avatar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_avatar != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _avatar == null && _latestMeasurement == null
              ? _buildNoDataView()
              : Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _build3DViewer(),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildMeasurementsPanel(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 100,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Body Scan Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Complete a body scan to view your 3D avatar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to body scan
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Body Scan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DViewer() {
    if (_avatar?.modelUrl == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Text(
            'Generating 3D Model...',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[900]!,
            Colors.black,
          ],
        ),
      ),
      child: ModelViewer(
        src: _avatar!.modelUrl!,
        alt: "3D Body Avatar",
        ar: true,
        autoRotate: true,
        cameraControls: true,
        backgroundColor: Colors.black,
        loading: Loading.eager,
        autoPlay: true,
      ),
    );
  }

  Widget _buildMeasurementsPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Body Measurements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildMeasurementGrid(),
            const SizedBox(height: 20),
            _buildBMICard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementGrid() {
    final measurements = _avatar?.measurements ?? _latestMeasurement?.estimatedMeasurements ?? {};
    final height = _latestMeasurement?.height ?? 0;
    final weight = _latestMeasurement?.weight ?? 0;

    final items = [
      {'label': 'Height', 'value': '${height.toStringAsFixed(0)} cm', 'icon': Icons.height},
      {'label': 'Weight', 'value': '${weight.toStringAsFixed(1)} kg', 'icon': Icons.monitor_weight},
      {'label': 'Chest', 'value': '${(measurements['chest'] ?? 0).toStringAsFixed(0)} cm', 'icon': Icons.accessibility},
      {'label': 'Waist', 'value': '${(measurements['waist'] ?? 0).toStringAsFixed(0)} cm', 'icon': Icons.accessibility_new},
      {'label': 'Hips', 'value': '${(measurements['hips'] ?? 0).toStringAsFixed(0)} cm', 'icon': Icons.accessibility},
      {'label': 'Shoulders', 'value': '${(measurements['shoulderWidth'] ?? 0).toStringAsFixed(0)} cm', 'icon': Icons.open_in_full},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                item['icon'] as IconData,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      item['value'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBMICard() {
    final bmi = _latestMeasurement?.bmi ?? _avatar?.bmi;
    if (bmi == null) return const SizedBox.shrink();

    String category;
    Color color;

    if (bmi < 18.5) {
      category = 'Underweight';
      color = Colors.blue;
    } else if (bmi < 25) {
      category = 'Normal';
      color = Colors.green;
    } else if (bmi < 30) {
      category = 'Overweight';
      color = Colors.orange;
    } else {
      category = 'Obese';
      color = Colors.red;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Body Mass Index (BMI)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'kg/m²',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
