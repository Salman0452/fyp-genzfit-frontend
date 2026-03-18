class OnboardingData {
  String? goal;
  String? fitnessLevel;
  String? workoutLocation;
  List<String> availableEquipment = [];
  int age = 25;
  String gender = 'male';
  double heightCm = 170;
  double weightKg = 70;
  int workoutDurationMinutes = 45;
  int workoutDaysPerWeek = 5;
  String cuisinePreference = 'pakistani';
  int mealsPerDay = 4;
  List<String> dietaryRestrictions = [];
  List<String> foodAllergies = [];
  List<String> healthConditions = [];

  OnboardingData();

  /// Populate from an existing preferences map (e.g. loaded from Firestore)
  factory OnboardingData.fromMap(Map<String, dynamic> map) {
    final data = OnboardingData();
    data.goal = map['goal'] as String?;
    data.fitnessLevel = map['fitness_level'] as String?;
    data.workoutLocation = map['workout_location'] as String?;
    data.availableEquipment = (map['available_equipment'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    data.age = (map['age'] as num?)?.toInt() ?? 25;
    data.gender = map['gender'] as String? ?? 'male';
    data.heightCm = (map['height_cm'] as num?)?.toDouble() ?? 170;
    data.weightKg = (map['weight_kg'] as num?)?.toDouble() ?? 70;
    data.workoutDurationMinutes =
        (map['workout_duration_minutes'] as num?)?.toInt() ?? 45;
    data.workoutDaysPerWeek =
        (map['workout_days_per_week'] as num?)?.toInt() ?? 5;
    data.cuisinePreference =
        map['cuisine_preference'] as String? ?? 'pakistani';
    data.mealsPerDay = (map['meals_per_day'] as num?)?.toInt() ?? 4;
    data.dietaryRestrictions = (map['dietary_restrictions'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    data.foodAllergies = (map['food_allergies'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    data.healthConditions = (map['health_conditions'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    return data;
  }

  /// Convert to preferences map for saving to Firestore / backend
  Map<String, dynamic> toPreferencesMap() {
    return {
      'goal': goal ?? 'fitness',
      'fitness_level': fitnessLevel ?? 'intermediate',
      'workout_location': workoutLocation ?? 'gym',
      'available_equipment': availableEquipment,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'workout_duration_minutes': workoutDurationMinutes,
      'workout_days_per_week': workoutDaysPerWeek,
      'cuisine_preference': cuisinePreference,
      'meals_per_day': mealsPerDay,
      'dietary_restrictions': dietaryRestrictions,
      'food_allergies': foodAllergies,
      'health_conditions': healthConditions,
      'disliked_exercises': [],
      'disliked_foods': [],
      'injury_limitations': [],
    };
  }

  OnboardingData copyWith({
    String? goal,
    String? fitnessLevel,
    String? workoutLocation,
    List<String>? availableEquipment,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    int? workoutDurationMinutes,
    int? workoutDaysPerWeek,
    String? cuisinePreference,
    int? mealsPerDay,
    List<String>? dietaryRestrictions,
    List<String>? foodAllergies,
    List<String>? healthConditions,
  }) {
    final copy = OnboardingData();
    copy.goal = goal ?? this.goal;
    copy.fitnessLevel = fitnessLevel ?? this.fitnessLevel;
    copy.workoutLocation = workoutLocation ?? this.workoutLocation;
    copy.availableEquipment =
        availableEquipment ?? List.from(this.availableEquipment);
    copy.age = age ?? this.age;
    copy.gender = gender ?? this.gender;
    copy.heightCm = heightCm ?? this.heightCm;
    copy.weightKg = weightKg ?? this.weightKg;
    copy.workoutDurationMinutes =
        workoutDurationMinutes ?? this.workoutDurationMinutes;
    copy.workoutDaysPerWeek = workoutDaysPerWeek ?? this.workoutDaysPerWeek;
    copy.cuisinePreference = cuisinePreference ?? this.cuisinePreference;
    copy.mealsPerDay = mealsPerDay ?? this.mealsPerDay;
    copy.dietaryRestrictions =
        dietaryRestrictions ?? List.from(this.dietaryRestrictions);
    copy.foodAllergies = foodAllergies ?? List.from(this.foodAllergies);
    copy.healthConditions =
        healthConditions ?? List.from(this.healthConditions);
    return copy;
  }
}
