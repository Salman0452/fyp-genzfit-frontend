import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:genzfit/services/body_analysis_service.dart';
import 'package:genzfit/services/anthropometric_service.dart';
import 'package:genzfit/widgets/pose_overlay_painter.dart';
import 'package:genzfit/utils/constants.dart';
import 'package:genzfit/widgets/custom_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:genzfit/providers/auth_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({super.key});

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _showGuidelines = true;
  List<File> _capturedPhotos = [];
  final BodyAnalysisService _bodyAnalysisService = BodyAnalysisService();
  final AnthropometricService _anthropometricService = AnthropometricService();
  Map<String, dynamic>? _analysisResult;
  Map<String, double>? _predictedMeasurements;

  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedGender = 'male';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required for body scanning'),
              backgroundColor: AppColors.error,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _isProcessing = true);

      // Capture image
      final XFile photo = await _cameraController!.takePicture();
      final File photoFile = File(photo.path);

      // Analyze pose
      final result = await _bodyAnalysisService.analyzePose(photo.path);

      setState(() {
        _capturedPhotos.add(photoFile);
        _analysisResult = result;
        _isProcessing = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Photo captured! Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // If we have at least one photo, show the review screen
      if (_capturedPhotos.length >= 1) {
        _showReviewDialog();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReviewDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Complete Your Scan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () {
                        setState(() {
                          _capturedPhotos.clear();
                          _analysisResult = null;
                          _predictedMeasurements = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Height input
                TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Height (cm) *',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.charcoal,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.height, color: AppColors.accent),
                  ),
                  onChanged: (value) => _updatePredictions(setModalState),
                ),
                const SizedBox(height: 16),

                // Weight input
                TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Weight (kg) *',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.charcoal,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.monitor_weight, color: AppColors.accent),
                  ),
                  onChanged: (value) => _updatePredictions(setModalState),
                ),
                const SizedBox(height: 16),

                // Age input
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Age *',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.charcoal,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.cake, color: AppColors.accent),
                  ),
                  onChanged: (value) => _updatePredictions(setModalState),
                ),
                const SizedBox(height: 16),

                // Gender selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gender *',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Male', style: TextStyle(color: AppColors.textPrimary)),
                              value: 'male',
                              groupValue: _selectedGender,
                              activeColor: AppColors.accent,
                              onChanged: (value) {
                                setModalState(() => _selectedGender = value!);
                                _updatePredictions(setModalState);
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Female', style: TextStyle(color: AppColors.textPrimary)),
                              value: 'female',
                              groupValue: _selectedGender,
                              activeColor: AppColors.accent,
                              onChanged: (value) {
                                setModalState(() => _selectedGender = value!);
                                _updatePredictions(setModalState);
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Predicted measurements section
                if (_predictedMeasurements != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.1),
                          AppColors.accent.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'AI-Predicted Body Measurements',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._buildMeasurementsList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes input
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.charcoal,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.notes, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                CustomButton(
                  text: 'Save Measurement',
                  onPressed: _saveMeasurement,
                  isLoading: _isProcessing,
                ),
                const SizedBox(height: 16),

                // Cancel button
                CustomButton(
                  text: 'Retake Photo',
                  onPressed: () {
                    setState(() {
                      _capturedPhotos.clear();
                      _analysisResult = null;
                      _predictedMeasurements = null;
                    });
                    Navigator.pop(context);
                  },
                  isOutlined: true,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveMeasurement() async {
    // Validate required fields
    if (_heightController.text.isEmpty || 
        _weightController.text.isEmpty || 
        _ageController.text.isEmpty || 
        _selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields (height, weight, age, gender)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final height = double.parse(_heightController.text);
      final weight = double.parse(_weightController.text);
      final age = int.parse(_ageController.text);

      // Combine ML Kit measurements with predicted measurements
      final mlKitMeasurements = Map<String, double>.from(
        _analysisResult?['measurements'] ?? {},
      );
      
      final allMeasurements = <String, double>{
        ...mlKitMeasurements,
        if (_predictedMeasurements != null) ..._predictedMeasurements!,
      };

      await _bodyAnalysisService.saveMeasurement(
        userId: userId,
        height: height,
        weight: weight,
        bodyLandmarks: _analysisResult?['landmarks'] ?? {},
        photos: _capturedPhotos,
        estimatedMeasurements: allMeasurements,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Close scan screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurement saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save measurement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _updatePredictions(StateSetter setModalState) {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    final age = int.tryParse(_ageController.text);

    if (height != null && weight != null && age != null && _selectedGender.isNotEmpty) {
      // Convert landmarks to Map<String, double> if available
      Map<String, double>? mlKitProportions;
      if (_analysisResult?['landmarks'] != null) {
        final landmarks = _analysisResult!['landmarks'] as Map<String, dynamic>;
        mlKitProportions = landmarks.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }

      final predictions = _anthropometricService.predictMeasurements(
        height: height,
        weight: weight,
        age: age,
        gender: _selectedGender,
        mlKitProportions: mlKitProportions,
      );

      setModalState(() {
        _predictedMeasurements = predictions;
      });
    }
  }

  List<Widget> _buildMeasurementsList() {
    if (_predictedMeasurements == null) return [];

    final measurements = [
      {'key': 'chest', 'label': 'Chest', 'icon': Icons.accessibility},
      {'key': 'waist', 'label': 'Waist', 'icon': Icons.straighten},
      {'key': 'hips', 'label': 'Hips', 'icon': Icons.accessibility_new},
      {'key': 'shoulders', 'label': 'Shoulders', 'icon': Icons.accessibility},
      {'key': 'neck', 'label': 'Neck', 'icon': Icons.face},
      {'key': 'bicep', 'label': 'Bicep', 'icon': Icons.fitness_center},
      {'key': 'forearm', 'label': 'Forearm', 'icon': Icons.pan_tool},
      {'key': 'wrist', 'label': 'Wrist', 'icon': Icons.watch},
      {'key': 'thigh', 'label': 'Thigh', 'icon': Icons.directions_walk},
      {'key': 'calf', 'label': 'Calf', 'icon': Icons.directions_run},
      {'key': 'ankle', 'label': 'Ankle', 'icon': Icons.airline_seat_legroom_normal},
      {'key': 'inseam', 'label': 'Inseam', 'icon': Icons.height},
    ];

    return measurements.where((m) => _predictedMeasurements!.containsKey(m['key'])).map((m) {
      final value = _predictedMeasurements![m['key'] as String];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(m['icon'] as IconData, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m['label'] as String,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${value?.toStringAsFixed(1)} cm',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Body Scan'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: Icon(
              _showGuidelines ? Icons.grid_on : Icons.grid_off,
              color: AppColors.accent,
            ),
            onPressed: () {
              setState(() => _showGuidelines = !_showGuidelines);
            },
          ),
        ],
      ),
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),

                // Pose overlay guidelines
                if (_showGuidelines)
                  Positioned.fill(
                    child: PoseOverlay(
                      showGuidelines: _showGuidelines,
                      guidelineColor: AppColors.accent,
                    ),
                  ),

                // Instructions
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    ),
                    child: const Text(
                      'Stand in the center with your arms slightly away from your body. Ensure good lighting.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Capture button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isProcessing ? null : _capturePhoto,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isProcessing
                              ? AppColors.textSecondary
                              : AppColors.accent,
                          border: Border.all(
                            color: AppColors.textPrimary,
                            width: 4,
                          ),
                        ),
                        child: _isProcessing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: AppColors.background,
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                ),

                // Photo count indicator
                if (_capturedPhotos.isNotEmpty)
                  Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_capturedPhotos.length} photo${_capturedPhotos.length > 1 ? 's' : ''} captured',
                          style: const TextStyle(
                            color: AppColors.background,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
              ),
            ),
    );
  }
}
