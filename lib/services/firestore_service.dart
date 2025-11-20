import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== User Operations ==========

  // Create user
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        return null;
      }
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: ${e.toString()}');
    }
  }

  // Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserModel.roleToString(role))
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users by role: ${e.toString()}');
    }
  }

  // Stream user data
  Stream<UserModel?> streamUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  // ========== Trainer Operations ==========

  // Get all verified trainers
  Future<List<UserModel>> getVerifiedTrainers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .where('verified', isEqualTo: true)
          .orderBy('rating', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get verified trainers: ${e.toString()}');
    }
  }

  // Search trainers by expertise
  Future<List<UserModel>> searchTrainersByExpertise(String expertise) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'trainer')
          .where('verified', isEqualTo: true)
          .where('expertise', arrayContains: expertise)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search trainers: ${e.toString()}');
    }
  }

  // ========== Admin Operations ==========

  // Get all users (admin only)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all users: ${e.toString()}');
    }
  }

  // Suspend user (admin only)
  Future<void> suspendUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'suspended',
      });
    } catch (e) {
      throw Exception('Failed to suspend user: ${e.toString()}');
    }
  }

  // Activate user (admin only)
  Future<void> activateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
      });
    } catch (e) {
      throw Exception('Failed to activate user: ${e.toString()}');
    }
  }

  // Verify trainer (admin only)
  Future<void> verifyTrainer(String trainerId) async {
    try {
      await _firestore.collection('users').doc(trainerId).update({
        'verified': true,
      });
    } catch (e) {
      throw Exception('Failed to verify trainer: ${e.toString()}');
    }
  }

  // ========== Platform Analytics ==========

  // Get platform stats
  Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      final doc = await _firestore
          .collection('platform_analytics')
          .doc('stats')
          .get();

      if (!doc.exists) {
        return {
          'totalUsers': 0,
          'totalClients': 0,
          'totalTrainers': 0,
          'activeSessions': 0,
          'totalRevenue': 0.0,
        };
      }

      return doc.data()!;
    } catch (e) {
      throw Exception('Failed to get platform stats: ${e.toString()}');
    }
  }

  // Update platform stats
  Future<void> updatePlatformStats(Map<String, dynamic> stats) async {
    try {
      await _firestore.collection('platform_analytics').doc('stats').set(
        {
          ...stats,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to update platform stats: ${e.toString()}');
    }
  }

  // ========== Generic Collection Operations ==========

  // Create document
  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    try {
      final docRef = await _firestore.collection(collection).add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create document: ${e.toString()}');
    }
  }

  // Get document
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get document: ${e.toString()}');
    }
  }

  // Update document
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      throw Exception('Failed to update document: ${e.toString()}');
    }
  }

  // Delete document
  Future<void> deleteDocument(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
    } catch (e) {
      throw Exception('Failed to delete document: ${e.toString()}');
    }
  }

  // Stream collection
  Stream<QuerySnapshot> streamCollection(String collection) {
    return _firestore.collection(collection).snapshots();
  }
}
