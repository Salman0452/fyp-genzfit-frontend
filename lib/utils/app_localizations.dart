import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'app_name': 'GenZFit',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'update': 'Update',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'yes': 'Yes',
      'no': 'No',
      
      // Profile
      'my_profile': 'My Profile',
      'edit_profile': 'Edit Profile',
      'full_name': 'Full Name',
      'email': 'Email',
      'fitness_goal': 'Fitness Goal',
      'update_profile': 'Update Profile',
      'profile_updated': 'Profile updated successfully!',
      
      // Measurements
      'latest_scan': 'Latest Scan',
      'update_measurements': 'Update Measurements',
      'take_body_scan': 'Take Body Scan',
      'no_measurements_yet': 'No measurements yet',
      'take_first_scan': 'Take your first body scan to start tracking',
      'measurement_history': 'Measurement History',
      'height': 'Height',
      'weight': 'Weight',
      'bmi': 'BMI',
      'category': 'Category',
      'body_measurements': 'Body Measurements',
      
      // Settings
      'settings': 'Settings',
      'account': 'Account',
      'change_password': 'Change Password',
      'update_password': 'Update your password',
      'preferences': 'Preferences',
      'notifications': 'Notifications',
      'language': 'Language',
      'theme': 'Theme',
      'dark_mode': 'Dark mode (default)',
      'privacy_security': 'Privacy & Security',
      'privacy_policy': 'Privacy Policy',
      'terms_of_service': 'Terms of Service',
      'about': 'About',
      'help_support': 'Help & Support',
      'logout': 'Logout',
      'logout_confirm': 'Are you sure you want to logout?',
      
      // Goals
      'lose_weight': 'Lose Weight',
      'build_muscle': 'Build Muscle',
      'get_fit': 'Get Fit',
      'improve_health': 'Improve Health',
      'increase_strength': 'Increase Strength',
      'improve_flexibility': 'Improve Flexibility',
      'no_goal_set': 'No goal set',
      
      // Body Scan
      'body_scan': 'Body Scan',
      'complete_scan': 'Complete Your Scan',
      'age': 'Age',
      'gender': 'Gender',
      'male': 'Male',
      'female': 'Female',
      'ai_predicted_measurements': 'AI-Predicted Body Measurements',
      'notes': 'Notes',
      'save_measurement': 'Save Measurement',
      'retake_photo': 'Retake Photo',
      
      // Help & Support
      'need_help': 'Need Help?',
      'contact_support': 'Contact Support',
      'faq': 'Frequently Asked Questions',
      'troubleshooting': 'Troubleshooting',
      'still_need_help': 'Still Need Help?',
    },
    
    'ur': {
      // Common - اردو
      'app_name': 'جین زیڈ فٹ',
      'ok': 'ٹھیک ہے',
      'cancel': 'منسوخ کریں',
      'save': 'محفوظ کریں',
      'delete': 'حذف کریں',
      'edit': 'ترمیم کریں',
      'update': 'اپ ڈیٹ کریں',
      'loading': 'لوڈ ہو رہا ہے...',
      'error': 'خرابی',
      'success': 'کامیابی',
      'yes': 'ہاں',
      'no': 'نہیں',
      
      // Profile
      'my_profile': 'میری پروفائل',
      'edit_profile': 'پروفائل میں ترمیم کریں',
      'full_name': 'پورا نام',
      'email': 'ای میل',
      'fitness_goal': 'فٹنس کا ہدف',
      'update_profile': 'پروفائل اپ ڈیٹ کریں',
      'profile_updated': 'پروفائل کامیابی سے اپ ڈیٹ ہو گئی!',
      
      // Measurements
      'latest_scan': 'تازہ ترین اسکین',
      'update_measurements': 'پیمائش اپ ڈیٹ کریں',
      'take_body_scan': 'باڈی اسکین کریں',
      'no_measurements_yet': 'ابھی تک کوئی پیمائش نہیں',
      'take_first_scan': 'ٹریکنگ شروع کرنے کے لیے اپنا پہلا باڈی اسکین کریں',
      'measurement_history': 'پیمائش کی تاریخ',
      'height': 'قد',
      'weight': 'وزن',
      'bmi': 'بی ایم آئی',
      'category': 'زمرہ',
      'body_measurements': 'جسم کی پیمائش',
      
      // Settings
      'settings': 'ترتیبات',
      'account': 'اکاؤنٹ',
      'change_password': 'پاس ورڈ تبدیل کریں',
      'update_password': 'اپنا پاس ورڈ اپ ڈیٹ کریں',
      'preferences': 'ترجیحات',
      'notifications': 'اطلاعات',
      'language': 'زبان',
      'theme': 'تھیم',
      'dark_mode': 'ڈارک موڈ (ڈیفالٹ)',
      'privacy_security': 'رازداری اور سیکیورٹی',
      'privacy_policy': 'رازداری کی پالیسی',
      'terms_of_service': 'خدمات کی شرائط',
      'about': 'کے بارے میں',
      'help_support': 'مدد اور سپورٹ',
      'logout': 'لاگ آؤٹ',
      'logout_confirm': 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟',
      
      // Goals
      'lose_weight': 'وزن کم کریں',
      'build_muscle': 'پٹھے بنائیں',
      'get_fit': 'فٹ ہو جائیں',
      'improve_health': 'صحت بہتر بنائیں',
      'increase_strength': 'طاقت بڑھائیں',
      'improve_flexibility': 'لچک بہتر بنائیں',
      'no_goal_set': 'کوئی ہدف مقرر نہیں',
      
      // Body Scan
      'body_scan': 'باڈی اسکین',
      'complete_scan': 'اپنا اسکین مکمل کریں',
      'age': 'عمر',
      'gender': 'جنس',
      'male': 'مرد',
      'female': 'عورت',
      'ai_predicted_measurements': 'AI سے پیش گوئی شدہ جسم کی پیمائش',
      'notes': 'نوٹس',
      'save_measurement': 'پیمائش محفوظ کریں',
      'retake_photo': 'دوبارہ تصویر لیں',
      
      // Help & Support
      'need_help': 'مدد چاہیے؟',
      'contact_support': 'سپورٹ سے رابطہ کریں',
      'faq': 'اکثر پوچھے جانے والے سوالات',
      'troubleshooting': 'مسائل کا حل',
      'still_need_help': 'پھر بھی مدد چاہیے؟',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Helper method for easy access
  String get appName => translate('app_name');
  String get ok => translate('ok');
  String get cancel => translate('cancel');
  String get save => translate('save');
  String get delete => translate('delete');
  String get edit => translate('edit');
  String get update => translate('update');
  String get loading => translate('loading');
  String get error => translate('error');
  String get success => translate('success');
  
  // Profile
  String get myProfile => translate('my_profile');
  String get editProfile => translate('edit_profile');
  String get fullName => translate('full_name');
  String get email => translate('email');
  String get fitnessGoal => translate('fitness_goal');
  String get updateProfile => translate('update_profile');
  
  // Measurements
  String get latestScan => translate('latest_scan');
  String get updateMeasurements => translate('update_measurements');
  String get takeBodyScan => translate('take_body_scan');
  String get noMeasurementsYet => translate('no_measurements_yet');
  String get measurementHistory => translate('measurement_history');
  String get height => translate('height');
  String get weight => translate('weight');
  String get bmi => translate('bmi');
  String get category => translate('category');
  String get bodyMeasurements => translate('body_measurements');
  
  // Settings
  String get settings => translate('settings');
  String get account => translate('account');
  String get changePassword => translate('change_password');
  String get preferences => translate('preferences');
  String get notifications => translate('notifications');
  String get language => translate('language');
  String get theme => translate('theme');
  String get privacyPolicy => translate('privacy_policy');
  String get termsOfService => translate('terms_of_service');
  String get about => translate('about');
  String get helpSupport => translate('help_support');
  String get logout => translate('logout');
  
  // Goals
  String get loseWeight => translate('lose_weight');
  String get buildMuscle => translate('build_muscle');
  String get getFit => translate('get_fit');
  String get improveHealth => translate('improve_health');
  String get increaseStrength => translate('increase_strength');
  String get improveFlexibility => translate('improve_flexibility');
  
  // Body Scan
  String get bodyScan => translate('body_scan');
  String get completeScan => translate('complete_scan');
  String get age => translate('age');
  String get gender => translate('gender');
  String get male => translate('male');
  String get female => translate('female');
  String get notes => translate('notes');
  String get saveMeasurement => translate('save_measurement');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ur'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
