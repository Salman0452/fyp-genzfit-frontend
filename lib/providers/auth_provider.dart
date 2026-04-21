import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_preferences_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserPreferencesService _prefsService = UserPreferencesService();

  UserModel? _currentUser;
  User? _firebaseUser;
  bool _isLoading = false;
  String? _error;
  bool _lastSocialAuthIsNewUser = false;

  UserModel? get currentUser => _currentUser;
  UserModel? get userModel => _currentUser;
  User? get user => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get lastSocialAuthIsNewUser => _lastSocialAuthIsNewUser;

  AuthProvider() {
    _initializeAuthState();
    _checkCurrentUser();
  }

  // Check if there's already a logged in user (for app restart)
  Future<void> _checkCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      _firebaseUser = user;
      try {
        _currentUser = await _authService.getUserData(user.uid);

        if (_currentUser != null && !_currentUser!.isActive) {
          await _authService.signOut();
          _currentUser = null;
          _error = 'This account has been disabled by admin. Please contact support.';
        }

        notifyListeners();
      } catch (e) {
        _error = e.toString();
        notifyListeners();
      }
    }
  }

  // Initialize auth state
  void _initializeAuthState() {
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        try {
          _currentUser = await _authService.getUserData(user.uid);

          if (_currentUser != null && !_currentUser!.isActive) {
            await _authService.signOut();
            _currentUser = null;
            _error = 'This account has been disabled by admin. Please contact support.';
            notifyListeners();
            return;
          }

          notifyListeners();
          // Sync saved preferences to backend on every login / app restart
          _prefsService.loadPreferences(user.uid).catchError((e) {
            print('⚠️ Preferences sync on login failed: $e');
            return null;
          });
        } catch (e) {
          _error = e.toString();
          notifyListeners();
        }
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? goals,
    List<String>? expertise,
    double? hourlyRate,
    bool emailVerified = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        goals: goals,
        expertise: expertise,
        hourlyRate: hourlyRate,
        emailVerified: emailVerified,
      );
      _lastSocialAuthIsNewUser = false;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send email verification link to currently signed in user
  Future<bool> sendEmailVerificationLink() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.sendEmailVerificationLink();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Check and sync email verification state from Firebase Auth to Firestore
  Future<bool> syncEmailVerificationStatus() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final verified = await _authService.syncEmailVerificationStatus();
      if (verified && _currentUser != null) {
        _currentUser = _currentUser!.copyWith(emailVerified: true);
      }

      _isLoading = false;
      notifyListeners();
      return verified;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Resend verification link for email/password credentials
  Future<bool> resendEmailVerificationForCredentials({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resendEmailVerificationForCredentials(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.signIn(
        email: email,
        password: password,
      );
      _lastSocialAuthIsNewUser = false;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in / sign up with Google
  Future<bool> signInWithGoogle({
    UserRole? role,
    String? goals,
    List<String>? expertise,
    double? hourlyRate,
    String? nameOverride,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final socialResult = await _authService.signInWithGoogle(
        role: role,
        goals: goals,
        expertise: expertise,
        hourlyRate: hourlyRate,
        nameOverride: nameOverride,
      );
      _currentUser = socialResult.user;
      _lastSocialAuthIsNewUser = socialResult.isNewUser;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in / sign up with Facebook
  Future<bool> signInWithFacebook({
    UserRole? role,
    String? goals,
    List<String>? expertise,
    double? hourlyRate,
    String? nameOverride,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final socialResult = await _authService.signInWithFacebook(
        role: role,
        goals: goals,
        expertise: expertise,
        hourlyRate: hourlyRate,
        nameOverride: nameOverride,
      );
      _currentUser = socialResult.user;
      _lastSocialAuthIsNewUser = socialResult.isNewUser;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      _currentUser = null;
      _lastSocialAuthIsNewUser = false;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user data
  Future<void> updateUserData(Map<String, dynamic> data) async {
    try {
      if (_currentUser == null) return;

      _isLoading = true;
      notifyListeners();

      await _authService.updateUserData(_currentUser!.id, data);

      // Refresh user data
      _currentUser = await _authService.getUserData(_currentUser!.id);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resetPassword(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    try {
      if (_currentUser == null) return;
      _currentUser = await _authService.getUserData(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Refresh user (alias for refreshUserData)
  Future<void> refreshUser() async {
    await refreshUserData();
  }
}
