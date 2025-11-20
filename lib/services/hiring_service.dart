import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:genzfit/models/session_model.dart';

class HiringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a hiring request from client to trainer
  Future<String?> createHiringRequest({
    required String clientId,
    required String trainerId,
    required double amount,
    String? notes,
  }) async {
    try {
      final sessionData = {
        'clientId': clientId,
        'trainerId': trainerId,
        'status': 'requested',
        'amount': amount,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('sessions').add(sessionData);
      
      return docRef.id;
    } catch (e) {
      print('Error creating hiring request: $e');
      return null;
    }
  }

  /// Accept a hiring request (trainer action)
  Future<bool> acceptHiringRequest(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'active',
        'startDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get session details to create chat
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      
      // Create or get existing chat between client and trainer
      await _getOrCreateChat(
        sessionData['clientId'],
        sessionData['trainerId'],
      );

      return true;
    } catch (e) {
      print('Error accepting hiring request: $e');
      return false;
    }
  }

  /// Reject a hiring request (trainer action)
  Future<bool> rejectHiringRequest(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error rejecting hiring request: $e');
      return false;
    }
  }

  /// Cancel a session (client or trainer action)
  Future<bool> cancelSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error cancelling session: $e');
      return false;
    }
  }

  /// Complete a session (trainer action)
  Future<bool> completeSession(String sessionId) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'status': 'completed',
        'endDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get session details to update trainer earnings
      final sessionDoc = await _firestore.collection('sessions').doc(sessionId).get();
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final trainerId = sessionData['trainerId'];
      final amount = sessionData['amount'];

      if (amount != null) {
        // Update trainer's total earnings
        await _firestore.collection('users').doc(trainerId).update({
          'totalEarnings': FieldValue.increment(amount),
        });
      }

      return true;
    } catch (e) {
      print('Error completing session: $e');
      return false;
    }
  }

  /// Get all sessions for a user (client or trainer)
  Stream<List<SessionModel>> getUserSessions(String userId, {bool isTrainer = false}) {
    final field = isTrainer ? 'trainerId' : 'clientId';
    
    return _firestore
        .collection('sessions')
        .where(field, isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SessionModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get pending requests for a trainer
  Stream<List<SessionModel>> getPendingRequests(String trainerId) {
    return _firestore
        .collection('sessions')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'requested')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SessionModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get active sessions for a user
  Stream<List<SessionModel>> getActiveSessions(String userId, {bool isTrainer = false}) {
    final field = isTrainer ? 'trainerId' : 'clientId';
    
    return _firestore
        .collection('sessions')
        .where(field, isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SessionModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Check if client already has a pending or active request with trainer
  Future<bool> hasExistingRequest(String clientId, String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('clientId', isEqualTo: clientId)
          .where('trainerId', isEqualTo: trainerId)
          .where('status', whereIn: ['requested', 'active'])
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking existing request: $e');
      return false;
    }
  }

  /// Get or create a chat between client and trainer
  Future<String> _getOrCreateChat(String clientId, String trainerId) async {
    // Check if chat already exists
    final existingChat = await _firestore
        .collection('chats')
        .where('participants', arrayContains: clientId)
        .get();

    for (var doc in existingChat.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(trainerId)) {
        return doc.id;
      }
    }

    // Create new chat
    final chatData = {
      'participants': [clientId, trainerId],
      'lastMessage': {
        'text': 'Session started',
        'senderId': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      },
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {
        clientId: 0,
        trainerId: 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('chats').add(chatData);
    
    // Add welcome message
    await _firestore
        .collection('chats')
        .doc(docRef.id)
        .collection('messages')
        .add({
      'senderId': 'system',
      'text': 'Your session has been accepted. Start chatting!',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Get chat ID for a session
  Future<String?> getChatForSession(String clientId, String trainerId) async {
    try {
      final existingChat = await _firestore
          .collection('chats')
          .where('participants', arrayContains: clientId)
          .get();

      for (var doc in existingChat.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(trainerId)) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      print('Error getting chat: $e');
      return null;
    }
  }

  /// Update session plan
  Future<bool> updateSessionPlan(String sessionId, Map<String, dynamic> plan) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'plan': plan,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating session plan: $e');
      return false;
    }
  }

  /// Add notes to session
  Future<bool> addSessionNotes(String sessionId, String notes) async {
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding session notes: $e');
      return false;
    }
  }

  /// Get session statistics for trainer
  Future<Map<String, dynamic>> getTrainerStats(String trainerId) async {
    try {
      final snapshot = await _firestore
          .collection('sessions')
          .where('trainerId', isEqualTo: trainerId)
          .get();

      int totalSessions = snapshot.docs.length;
      int activeSessions = 0;
      int completedSessions = 0;
      double totalEarnings = 0.0;
      Set<String> uniqueClients = {};

      for (var doc in snapshot.docs) {
        final session = SessionModel.fromFirestore(doc);
        uniqueClients.add(session.clientId);

        if (session.status == SessionStatus.active) {
          activeSessions++;
        } else if (session.status == SessionStatus.completed) {
          completedSessions++;
          if (session.amount != null) {
            totalEarnings += session.amount!;
          }
        }
      }

      return {
        'totalSessions': totalSessions,
        'activeSessions': activeSessions,
        'completedSessions': completedSessions,
        'totalClients': uniqueClients.length,
        'totalEarnings': totalEarnings,
      };
    } catch (e) {
      print('Error getting trainer stats: $e');
      return {
        'totalSessions': 0,
        'activeSessions': 0,
        'completedSessions': 0,
        'totalClients': 0,
        'totalEarnings': 0.0,
      };
    }
  }
}
