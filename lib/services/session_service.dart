import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a session request
  Future<String> requestSession({
    required String clientId,
    required String trainerId,
    required double amount,
    String? notes,
  }) async {
    final session = SessionModel(
      id: '',
      clientId: clientId,
      trainerId: trainerId,
      status: SessionStatus.requested,
      amount: amount,
      notes: notes,
      createdAt: DateTime.now(),
    );

    final docRef =
        await _firestore.collection('sessions').add(session.toFirestore());
    return docRef.id;
  }

  // Accept session request (trainer)
  Future<void> acceptSession(String sessionId, DateTime startDate) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': SessionModel.statusToString(SessionStatus.active),
      'startDate': Timestamp.fromDate(startDate),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Update trainer's client count
    final session = await getSession(sessionId);
    if (session != null) {
      await _updateTrainerStats(session.trainerId, incrementClients: true);
    }
  }

  // Reject session request (trainer)
  Future<void> rejectSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': SessionModel.statusToString(SessionStatus.rejected),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Cancel session (client)
  Future<void> cancelSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': SessionModel.statusToString(SessionStatus.cancelled),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Complete session
  Future<void> completeSession(String sessionId, {double? finalAmount}) async {
    final session = await getSession(sessionId);
    if (session == null) return;

    await _firestore.collection('sessions').doc(sessionId).update({
      'status': SessionModel.statusToString(SessionStatus.completed),
      'endDate': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      if (finalAmount != null) 'amount': finalAmount,
    });

    // Update trainer's earnings
    await _updateTrainerStats(
      session.trainerId,
      addEarnings: finalAmount ?? session.amount ?? 0,
    );
  }

  // Get session by ID
  Future<SessionModel?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    if (!doc.exists) return null;
    return SessionModel.fromFirestore(doc);
  }

  // Get sessions for client
  Stream<List<SessionModel>> getClientSessions(String clientId) {
    return _firestore
        .collection('sessions')
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SessionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get sessions for trainer
  Stream<List<SessionModel>> getTrainerSessions(String trainerId) {
    return _firestore
        .collection('sessions')
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SessionModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get pending session requests for trainer
  Stream<List<SessionModel>> getTrainerPendingRequests(String trainerId) {
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

  // Get active sessions count for trainer
  Future<int> getActiveSessionsCount(String trainerId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs.length;
  }

  // Update session plan
  Future<void> updateSessionPlan(
    String sessionId,
    Map<String, dynamic> plan,
  ) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'plan': plan,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Private method to update trainer stats
  Future<void> _updateTrainerStats(
    String trainerId, {
    bool incrementClients = false,
    double addEarnings = 0,
  }) async {
    final trainerRef = _firestore.collection('trainers').doc(trainerId);
    final trainerDoc = await trainerRef.get();

    if (trainerDoc.exists) {
      final data = trainerDoc.data() as Map<String, dynamic>;
      final currentClients = data['clients'] ?? 0;
      final currentEarnings = (data['totalEarnings'] ?? 0).toDouble();

      await trainerRef.update({
        if (incrementClients) 'clients': currentClients + 1,
        if (addEarnings > 0) 'totalEarnings': currentEarnings + addEarnings,
      });
    }
  }

  // Check if client has active session with trainer
  Future<bool> hasActiveSession(String clientId, String trainerId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('clientId', isEqualTo: clientId)
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Check if client has pending request with trainer
  Future<bool> hasPendingRequest(String clientId, String trainerId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('clientId', isEqualTo: clientId)
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'requested')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
