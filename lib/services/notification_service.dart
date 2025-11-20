import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Initialize push notifications
  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
      return;
    }

    // Get FCM token
    final token = await _messaging.getToken();
    print('FCM Token: $token');

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Initialize local notifications for Android
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Handle notification tap from local notification
  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToDatabase(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Delete FCM token from Firestore (on logout)
  Future<void> deleteTokenFromDatabase(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': FieldValue.delete(),
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.notification?.title}');
    
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'GenZFit',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Handle notification tap (app in background)
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    
    final data = message.data;
    final type = data['type'];

    // TODO: Navigate based on notification type
    switch (type) {
      case 'chat':
        // Navigate to chat screen
        print('Navigate to chat: ${data['chatId']}');
        break;
      case 'session_request':
        // Navigate to trainer dashboard
        print('Navigate to session request');
        break;
      case 'session_accepted':
        // Navigate to active sessions
        print('Navigate to active sessions');
        break;
      default:
        print('Unknown notification type: $type');
    }
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'genzfit_channel',
      'GenZFit Notifications',
      channelDescription: 'Notifications for chat messages and session updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Send notification to specific user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken == null) {
        print('User has no FCM token');
        return;
      }

      // Create notification document for Cloud Functions to process
      await _firestore.collection('notifications').add({
        'userId': userId,
        'token': fcmToken,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      print('Notification queued for user: $userId');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  /// Send chat message notification
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await sendNotificationToUser(
      userId: recipientId,
      title: senderName,
      body: message,
      data: {
        'type': 'chat',
        'chatId': chatId,
        'senderId': recipientId,
      },
    );
  }

  /// Send session request notification
  Future<void> sendSessionRequestNotification({
    required String trainerId,
    required String clientName,
    required String sessionId,
  }) async {
    await sendNotificationToUser(
      userId: trainerId,
      title: 'New Session Request',
      body: '$clientName wants to hire you as their trainer',
      data: {
        'type': 'session_request',
        'sessionId': sessionId,
      },
    );
  }

  /// Send session accepted notification
  Future<void> sendSessionAcceptedNotification({
    required String clientId,
    required String trainerName,
    required String sessionId,
  }) async {
    await sendNotificationToUser(
      userId: clientId,
      title: 'Session Accepted',
      body: '$trainerName accepted your training request',
      data: {
        'type': 'session_accepted',
        'sessionId': sessionId,
      },
    );
  }

  /// Send session rejected notification
  Future<void> sendSessionRejectedNotification({
    required String clientId,
    required String trainerName,
    required String sessionId,
  }) async {
    await sendNotificationToUser(
      userId: clientId,
      title: 'Session Request Declined',
      body: '$trainerName declined your training request',
      data: {
        'type': 'session_rejected',
        'sessionId': sessionId,
      },
    );
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  // Handle background message
}
