import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../models/user_model.dart';

class SocialAuthResult {
  final UserModel user;
  final bool isNewUser;

  SocialAuthResult({
    required this.user,
    required this.isNewUser,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUp({
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
      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user');
      }

      // Update display name
      await user.updateDisplayName(name);

      // Create user model
      final userModel = UserModel(
        id: user.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
        status: 'active',
        emailVerified: emailVerified,
        goals: role == UserRole.client ? goals : null,
        expertise: role == UserRole.trainer ? expertise : null,
        hourlyRate: role == UserRole.trainer ? hourlyRate : null,
        rating: role == UserRole.trainer ? 0.0 : null,
        verified: role == UserRole.trainer ? false : null,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());

      // If trainer, create trainer profile
      if (role == UserRole.trainer) {
        await _firestore.collection('trainers').doc(user.uid).set({
          'userId': user.uid,
          'bio': '',
          'expertise': expertise ?? [],
          'certifications': [],
          'videoUrls': [],
          'hourlyRate': hourlyRate ?? 0.0,
          'rating': 0.0,
          'clients': 0,
          'totalEarnings': 0.0,
          'verified': false,
          'availability': {},
        });
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign up failed. Please try again.');
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to sign in');
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw Exception('Failed to refresh user session. Please try again.');
      }

      if (!refreshedUser.emailVerified) {
        await _auth.signOut();
        throw Exception(
          'Please verify your email first. We sent you a verification link.',
        );
      }

      // Get user data from Firestore
      final doc = await _firestore.collection('users').doc(refreshedUser.uid).get();
      if (!doc.exists) {
        throw Exception('User data not found');
      }

      if ((doc.data()?['emailVerified'] as bool?) != true) {
        await _firestore.collection('users').doc(refreshedUser.uid).update({
          'emailVerified': true,
        });
      }

      return UserModel.fromMap(doc.data()!);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('Please verify your email first')) {
        rethrow;
      }
      throw Exception('Login failed. Please try again.');
    }
  }

  // Send verification email link for currently signed-in email/password user
  Future<void> sendEmailVerificationLink() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user signed in');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to send verification email. Please try again.');
    }
  }

  // Sign in temporarily to resend verification email, then sign out
  Future<void> resendEmailVerificationForCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('No user found for provided credentials.');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }

      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to resend verification email. Please try again.');
    }
  }

  // Refresh Firebase user and sync verified state to Firestore
  Future<bool> syncEmailVerificationStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        return false;
      }

      await _firestore.collection('users').doc(refreshedUser.uid).set({
        'emailVerified': true,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      throw Exception('Failed to check email verification status.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FacebookAuth.instance.logOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Sign in / sign up with Google
  Future<SocialAuthResult> signInWithGoogle({
    UserRole? role,
    String? goals,
    List<String>? expertise,
    double? hourlyRate,
    String? nameOverride,
  }) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Google authentication failed. Please try again.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Failed to sign in with Google.');
      }

      return _getOrCreateSocialUser(
        firebaseUser,
        role: role,
        goals: goals,
        expertise: expertise,
        hourlyRate: hourlyRate,
        nameOverride: nameOverride,
        emailVerified: true,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        rethrow;
      }
      throw Exception('Google sign in failed: ${e.toString()}');
    }
  }

  // Sign in / sign up with Facebook
  Future<SocialAuthResult> signInWithFacebook({
    UserRole? role,
    String? goals,
    List<String>? expertise,
    double? hourlyRate,
    String? nameOverride,
  }) async {
    try {
      final loginResult = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );

      if (loginResult.status == LoginStatus.cancelled) {
        throw Exception('Facebook sign in was cancelled.');
      }

      if (loginResult.status != LoginStatus.success ||
          loginResult.accessToken == null) {
        throw Exception(
          'Facebook sign in failed: ${loginResult.message ?? loginResult.status.name}',
        );
      }

      final credential = FacebookAuthProvider.credential(
        loginResult.accessToken!.tokenString,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Failed to sign in with Facebook.');
      }

      final userData = await FacebookAuth.instance.getUserData(
        fields: 'name,email,picture.width(200)',
      );
      final facebookEmail = userData['email'] as String?;
      final facebookName = userData['name'] as String?;

      if ((firebaseUser.email == null || firebaseUser.email!.isEmpty) &&
          (facebookEmail == null || facebookEmail.isEmpty)) {
        throw Exception(
            'Facebook account did not provide an email. Please add an email to Facebook and try again.');
      }

      return _getOrCreateSocialUser(
        firebaseUser,
        role: role,
        goals: goals,
        expertise: expertise,
        hourlyRate: hourlyRate,
        nameOverride: nameOverride ?? facebookName,
        emailOverride: facebookEmail,
        emailVerified: true,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('Facebook sign in was cancelled')) {
        rethrow;
      }
      throw Exception('Facebook sign in failed: ${e.toString()}');
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        return null;
      }
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

  // Update user data
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user data: ${e.toString()}');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed. Please try again.');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // If trainer, delete trainer profile
      final trainerDoc =
          await _firestore.collection('trainers').doc(user.uid).get();
      if (trainerDoc.exists) {
        await _firestore.collection('trainers').doc(user.uid).delete();
      }

      // Delete auth user
      await user.delete();
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign in is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return 'Please log in again to perform this action.';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account.';
      default:
        return 'Login failed. Please check your credentials and try again.';
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  // Reauthenticate user (needed for sensitive operations)
  Future<void> reauthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user signed in');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      throw Exception('Reauthentication failed: ${e.toString()}');
    }
  }

  Future<SocialAuthResult> _getOrCreateSocialUser(
    User firebaseUser, {
    UserRole? role,
    String? goals,
    List<String>? expertise,
    double? hourlyRate,
    String? nameOverride,
    String? emailOverride,
    bool emailVerified = true,
  }) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final existingDoc = await docRef.get();

    if (existingDoc.exists) {
      return SocialAuthResult(
        user: UserModel.fromMap(existingDoc.data()!),
        isNewUser: false,
      );
    }

    final selectedRole = role ?? UserRole.client;
    final email = emailOverride ?? firebaseUser.email;
    final name = nameOverride ?? firebaseUser.displayName ?? 'GenZFit User';

    if (email == null || email.isEmpty) {
      throw Exception('No email found for this account.');
    }

    final userModel = UserModel(
      id: firebaseUser.uid,
      email: email,
      name: name,
      avatarUrl: firebaseUser.photoURL,
      role: selectedRole,
      createdAt: DateTime.now(),
      status: 'active',
      emailVerified: emailVerified,
      goals: selectedRole == UserRole.client ? goals : null,
      expertise: selectedRole == UserRole.trainer ? expertise : null,
      hourlyRate: selectedRole == UserRole.trainer ? hourlyRate : null,
      rating: selectedRole == UserRole.trainer ? 0.0 : null,
      verified: selectedRole == UserRole.trainer ? false : null,
    );

    await docRef.set(userModel.toMap());

    if (selectedRole == UserRole.trainer) {
      await _firestore.collection('trainers').doc(firebaseUser.uid).set({
        'userId': firebaseUser.uid,
        'bio': '',
        'expertise': expertise ?? [],
        'certifications': [],
        'videoUrls': [],
        'hourlyRate': hourlyRate ?? 0.0,
        'rating': 0.0,
        'clients': 0,
        'totalEarnings': 0.0,
        'verified': false,
        'availability': {},
      });
    }

    return SocialAuthResult(
      user: userModel,
      isNewUser: true,
    );
  }
}
