import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logAction({
    required String adminId,
    required String actionType,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('admin_action_logs').add({
        'adminId': adminId,
        'actionType': actionType,
        'entityType': entityType,
        'entityId': entityId,
        'metadata': metadata ?? <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Audit logging must never block user operations.
    }
  }
}
