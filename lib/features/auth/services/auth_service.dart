import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Trainer Signup
  Future<String?> signUpTrainer({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('trainers').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'uid': userCredential.user!.uid,
        'role': 'trainer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Trainer Login
  Future<String?> loginTrainer({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Verify user is a trainer
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('trainers').doc(uid).get();
        if (!doc.exists) {
          await _auth.signOut();
          return 'This account is not registered as a trainer.';
        }
      }
      
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Seeker Signup
  Future<String?> signUpSeeker({
    required String name,
    required String email,
    required String password,
    required int age,
    required double weight,
    required double height,
    required String gender,
    required String fitnessGoal,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('seekers').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'uid': userCredential.user!.uid,
        'role': 'seeker',
        'age': age,
        'weight': weight,
        'height': height,
        'gender': gender,
        'fitnessGoal': fitnessGoal,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Seeker Login
  Future<String?> loginSeeker({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Verify user is a seeker
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('seekers').doc(uid).get();
        if (!doc.exists) {
          await _auth.signOut();
          return 'This account is not registered as a seeker.';
        }
      }

      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Get seeker data
  Future<Map<String, dynamic>?> getSeekerData() async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return null;

      final doc = await _firestore.collection('seekers').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get trainer data
  Future<Map<String, dynamic>?> getTrainerData() async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return null;
      
      final doc = await _firestore.collection('trainers').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Get all trainers
  Future<List<Map<String, dynamic>>> getAllTrainers() async {
    try {
      final querySnapshot = await _firestore.collection('trainers').get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // Update seeker profile
  Future<String?> updateSeekerProfile({
    required String name,
    required int age,
    required double weight,
    required double height,
    required String gender,
    required String fitnessGoal,
  }) async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return 'User not logged in';

      await _firestore.collection('seekers').doc(uid).update({
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'gender': gender,
        'fitnessGoal': fitnessGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } catch (e) {
      return 'Failed to update profile. Please try again.';
    }
  }

  // Update password
  Future<String?> updatePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'Failed to update password. Please try again.';
    }
  }
}