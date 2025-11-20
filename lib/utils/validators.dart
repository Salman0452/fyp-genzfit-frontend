class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }

  // Phone validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]+$');
    
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    
    if (value.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Number validation
  static String? validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }
    
    return null;
  }

  // Positive number validation
  static String? validatePositiveNumber(String? value, String fieldName) {
    final error = validateNumber(value, fieldName);
    if (error != null) return error;
    
    final number = double.parse(value!);
    if (number <= 0) {
      return '$fieldName must be greater than 0';
    }
    
    return null;
  }

  // Hourly rate validation
  static String? validateHourlyRate(String? value) {
    return validatePositiveNumber(value, 'Hourly rate');
  }

  // Height validation (cm)
  static String? validateHeight(String? value) {
    final error = validatePositiveNumber(value, 'Height');
    if (error != null) return error;
    
    final height = double.parse(value!);
    if (height < 50 || height > 300) {
      return 'Height must be between 50 and 300 cm';
    }
    
    return null;
  }

  // Weight validation (kg)
  static String? validateWeight(String? value) {
    final error = validatePositiveNumber(value, 'Weight');
    if (error != null) return error;
    
    final weight = double.parse(value!);
    if (weight < 20 || weight > 500) {
      return 'Weight must be between 20 and 500 kg';
    }
    
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  }
}
