import 'dart:math';

/// Service for predicting body measurements using anthropometric data
/// Based on scientific body proportion research and population averages
class AnthropometricService {
  /// Predicts all body measurements from basic user data and ML Kit proportions
  Map<String, double> predictMeasurements({
    required double height, // in cm
    required double weight, // in kg
    required int age,
    required String gender, // 'male' or 'female'
    Map<String, double>? mlKitProportions,
  }) {
    final isMale = gender.toLowerCase() == 'male';
    
    // Calculate BMI
    final bmi = weight / pow(height / 100, 2);
    
    // Calculate body frame size (based on height and weight)
    final frameSize = _calculateFrameSize(height, weight, isMale);
    
    // Base measurements using anthropometric formulas
    final measurements = <String, double>{};
    
    // Chest/Bust circumference
    measurements['chest'] = _predictChest(height, weight, bmi, isMale, frameSize);
    
    // Waist circumference
    measurements['waist'] = _predictWaist(height, weight, bmi, isMale, frameSize);
    
    // Hip circumference
    measurements['hips'] = _predictHips(height, weight, bmi, isMale, frameSize);
    
    // Shoulder width (can be refined with ML Kit data)
    if (mlKitProportions != null && mlKitProportions.containsKey('shoulderWidth')) {
      measurements['shoulderWidth'] = _calibrateMeasurement(
        mlKitProportions['shoulderWidth']!,
        height,
        _predictShoulderWidth(height, isMale, frameSize),
      );
    } else {
      measurements['shoulderWidth'] = _predictShoulderWidth(height, isMale, frameSize);
    }
    
    // Neck circumference
    measurements['neck'] = _predictNeck(height, weight, isMale);
    
    // Arm measurements
    measurements['armLength'] = _predictArmLength(height, isMale);
    measurements['bicep'] = _predictBicep(height, weight, isMale, frameSize);
    measurements['forearm'] = _predictForearm(height, weight, isMale);
    measurements['wrist'] = _predictWrist(height, isMale, frameSize);
    
    // Leg measurements
    measurements['inseam'] = _predictInseam(height, isMale);
    measurements['thigh'] = _predictThigh(height, weight, isMale, frameSize);
    measurements['calf'] = _predictCalf(height, weight, isMale, frameSize);
    measurements['ankle'] = _predictAnkle(height, isMale, frameSize);
    
    // Torso length (can be refined with ML Kit)
    if (mlKitProportions != null && mlKitProportions.containsKey('torsoLength')) {
      measurements['torsoLength'] = _calibrateMeasurement(
        mlKitProportions['torsoLength']!,
        height,
        height * (isMale ? 0.30 : 0.29),
      );
    } else {
      measurements['torsoLength'] = height * (isMale ? 0.30 : 0.29);
    }
    
    return measurements;
  }
  
  /// Calculate body frame size: small, medium, large
  String _calculateFrameSize(double height, double weight, bool isMale) {
    final bmi = weight / pow(height / 100, 2);
    
    if (isMale) {
      if (bmi < 20) return 'small';
      if (bmi < 25) return 'medium';
      return 'large';
    } else {
      if (bmi < 19) return 'small';
      if (bmi < 24) return 'medium';
      return 'large';
    }
  }
  
  /// Predict chest/bust circumference
  double _predictChest(double height, double weight, double bmi, bool isMale, String frameSize) {
    // Base formula: proportional to height and weight
    double baseChest;
    
    if (isMale) {
      // Male chest average: ~56-57% of height
      baseChest = height * 0.565;
      
      // Adjust for weight/BMI
      if (bmi < 18.5) {
        baseChest *= 0.95;
      } else if (bmi > 25) {
        baseChest *= 1.05 + ((bmi - 25) * 0.01);
      }
    } else {
      // Female bust average: ~53-54% of height
      baseChest = height * 0.535;
      
      // Adjust for weight/BMI
      if (bmi < 18.5) {
        baseChest *= 0.92;
      } else if (bmi > 25) {
        baseChest *= 1.08 + ((bmi - 25) * 0.015);
      }
    }
    
    return baseChest.clamp(60.0, 150.0);
  }
  
  /// Predict waist circumference
  double _predictWaist(double height, double weight, double bmi, bool isMale, String frameSize) {
    double baseWaist;
    
    if (isMale) {
      // Male waist average: ~45-47% of height (varies significantly with BMI)
      baseWaist = height * 0.46;
      
      // Strong correlation with BMI for waist
      if (bmi < 18.5) {
        baseWaist *= 0.85;
      } else if (bmi > 25) {
        baseWaist *= 1.1 + ((bmi - 25) * 0.025);
      }
    } else {
      // Female waist average: ~42-43% of height
      baseWaist = height * 0.42;
      
      if (bmi < 18.5) {
        baseWaist *= 0.88;
      } else if (bmi > 25) {
        baseWaist *= 1.12 + ((bmi - 25) * 0.03);
      }
    }
    
    return baseWaist.clamp(50.0, 140.0);
  }
  
  /// Predict hip circumference
  double _predictHips(double height, double weight, double bmi, bool isMale, String frameSize) {
    double baseHips;
    
    if (isMale) {
      // Male hips average: ~53% of height
      baseHips = height * 0.53;
      
      if (bmi < 18.5) {
        baseHips *= 0.93;
      } else if (bmi > 25) {
        baseHips *= 1.05 + ((bmi - 25) * 0.015);
      }
    } else {
      // Female hips average: ~55-57% of height (wider than males)
      baseHips = height * 0.56;
      
      if (bmi < 18.5) {
        baseHips *= 0.92;
      } else if (bmi > 25) {
        baseHips *= 1.07 + ((bmi - 25) * 0.02);
      }
    }
    
    return baseHips.clamp(70.0, 150.0);
  }
  
  /// Predict shoulder width
  double _predictShoulderWidth(double height, bool isMale, String frameSize) {
    // Shoulder width is ~25-27% of height for males, 23-25% for females
    double base = height * (isMale ? 0.26 : 0.24);
    
    // Adjust for frame size
    if (frameSize == 'small') {
      base *= 0.95;
    } else if (frameSize == 'large') {
      base *= 1.05;
    }
    
    return base.clamp(30.0, 60.0);
  }
  
  /// Predict neck circumference
  double _predictNeck(double height, double weight, bool isMale) {
    // Neck circumference formula based on height and weight
    double baseNeck;
    
    if (isMale) {
      baseNeck = 35 + (weight - 70) * 0.1 + (height - 170) * 0.05;
    } else {
      baseNeck = 32 + (weight - 60) * 0.08 + (height - 160) * 0.04;
    }
    
    return baseNeck.clamp(28.0, 50.0);
  }
  
  /// Predict arm length (shoulder to wrist)
  double _predictArmLength(double height, bool isMale) {
    // Arm length is ~38-40% of height
    return height * (isMale ? 0.39 : 0.38);
  }
  
  /// Predict bicep circumference
  double _predictBicep(double height, double weight, bool isMale, String frameSize) {
    double baseBicep;
    
    if (isMale) {
      baseBicep = 25 + (weight - 70) * 0.15;
    } else {
      baseBicep = 23 + (weight - 60) * 0.12;
    }
    
    if (frameSize == 'small') baseBicep *= 0.95;
    if (frameSize == 'large') baseBicep *= 1.05;
    
    return baseBicep.clamp(20.0, 50.0);
  }
  
  /// Predict forearm circumference
  double _predictForearm(double height, double weight, bool isMale) {
    double baseForearm;
    
    if (isMale) {
      baseForearm = 23 + (weight - 70) * 0.1;
    } else {
      baseForearm = 21 + (weight - 60) * 0.08;
    }
    
    return baseForearm.clamp(18.0, 40.0);
  }
  
  /// Predict wrist circumference
  double _predictWrist(double height, bool isMale, String frameSize) {
    double baseWrist = isMale ? 17.0 : 15.0;
    
    if (frameSize == 'small') baseWrist -= 1.0;
    if (frameSize == 'large') baseWrist += 1.0;
    
    return baseWrist.clamp(13.0, 22.0);
  }
  
  /// Predict inseam (leg length)
  double _predictInseam(double height, bool isMale) {
    // Inseam is ~45-47% of height
    return height * (isMale ? 0.46 : 0.45);
  }
  
  /// Predict thigh circumference
  double _predictThigh(double height, double weight, bool isMale, String frameSize) {
    double baseThigh;
    
    if (isMale) {
      baseThigh = 50 + (weight - 70) * 0.2;
    } else {
      baseThigh = 52 + (weight - 60) * 0.25;
    }
    
    if (frameSize == 'small') baseThigh *= 0.95;
    if (frameSize == 'large') baseThigh *= 1.05;
    
    return baseThigh.clamp(40.0, 80.0);
  }
  
  /// Predict calf circumference
  double _predictCalf(double height, double weight, bool isMale, String frameSize) {
    double baseCalf;
    
    if (isMale) {
      baseCalf = 35 + (weight - 70) * 0.12;
    } else {
      baseCalf = 33 + (weight - 60) * 0.15;
    }
    
    if (frameSize == 'small') baseCalf *= 0.95;
    if (frameSize == 'large') baseCalf *= 1.05;
    
    return baseCalf.clamp(28.0, 50.0);
  }
  
  /// Predict ankle circumference
  double _predictAnkle(double height, bool isMale, String frameSize) {
    double baseAnkle = isMale ? 23.0 : 21.0;
    
    if (frameSize == 'small') baseAnkle -= 1.0;
    if (frameSize == 'large') baseAnkle += 1.0;
    
    return baseAnkle.clamp(18.0, 30.0);
  }
  
  /// Calibrate ML Kit proportions to real measurements
  double _calibrateMeasurement(
    double mlKitValue,
    double height,
    double predictedValue,
  ) {
    // ML Kit gives pixel-based measurements
    // We use predicted value as reference and adjust based on ML Kit proportions
    // This is a simplified calibration - in production, you'd want more sophisticated methods
    
    // If ML Kit value seems reasonable (not 0 or extremely high), use it to refine prediction
    if (mlKitValue > 10 && mlKitValue < 1000) {
      // Weighted average: 70% prediction, 30% ML Kit adjusted
      return predictedValue * 0.7 + (mlKitValue * 0.3);
    }
    
    return predictedValue;
  }
  
  /// Get measurement category label
  String getMeasurementLabel(String key) {
    const labels = {
      'chest': 'Chest',
      'waist': 'Waist',
      'hips': 'Hips',
      'shoulderWidth': 'Shoulder Width',
      'neck': 'Neck',
      'armLength': 'Arm Length',
      'bicep': 'Bicep',
      'forearm': 'Forearm',
      'wrist': 'Wrist',
      'inseam': 'Inseam',
      'thigh': 'Thigh',
      'calf': 'Calf',
      'ankle': 'Ankle',
      'torsoLength': 'Torso Length',
    };
    
    return labels[key] ?? key;
  }
  
  /// Get measurement description/help text
  String getMeasurementDescription(String key) {
    const descriptions = {
      'chest': 'Around the fullest part of the chest',
      'waist': 'Around the natural waistline',
      'hips': 'Around the fullest part of the hips',
      'shoulderWidth': 'From shoulder point to shoulder point',
      'neck': 'Around the base of the neck',
      'armLength': 'From shoulder to wrist',
      'bicep': 'Around the fullest part of upper arm',
      'forearm': 'Around the fullest part of forearm',
      'wrist': 'Around the wrist bone',
      'inseam': 'From crotch to ankle',
      'thigh': 'Around the fullest part of thigh',
      'calf': 'Around the fullest part of calf',
      'ankle': 'Around the ankle bone',
      'torsoLength': 'From shoulder to waist',
    };
    
    return descriptions[key] ?? '';
  }
}
