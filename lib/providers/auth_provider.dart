import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  User? _firebaseUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  UserModel? get userModel => _currentUser;
  User? get user => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  
  AuthProvider() {
    _initializeAuthState();
  }

  // Initialize auth state
  void _initializeAuthState() {
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        try {
          _currentUser = await _authService.getUserData(user.uid);
          notifyListeners();
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
      );

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

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      _currentUser = null;

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
