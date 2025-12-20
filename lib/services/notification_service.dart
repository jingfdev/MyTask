import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late FirebaseMessaging firebaseMessaging;

  // Stream controllers for notification events
  final StreamController<Map<String, dynamic>> _notificationTapStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<RemoteMessage> _messageReceivedStream =
      StreamController<RemoteMessage>.broadcast();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    firebaseMessaging = FirebaseMessaging.instance;
  }

  /// Get stream for notification taps
  Stream<Map<String, dynamic>> get notificationTapStream =>
      _notificationTapStream.stream;

  /// Get stream for incoming FCM messages
  Stream<RemoteMessage> get messageReceivedStream =>
      _messageReceivedStream.stream;

  /// Initialize both local and push notifications
  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Initialize Firebase Cloud Messaging
    await _initializeFirebaseMessaging();
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request notification permissions
    NotificationSettings settings =
        await firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permissions granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ Notification permissions provisional');
    } else {
      print('❌ Notification permissions denied');
    }

    // Get FCM token
    String? token = await firebaseMessaging.getToken();
    print('🔑 FCM Token: $token');

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to background message (set up in main.dart)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    return await firebaseMessaging.getToken();
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground message received: ${message.messageId}');
    _messageReceivedStream.add(message);

    // Show notification if app is in foreground
    if (message.notification != null) {
      showInstantNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data,
      );
    }
  }

  /// Handle message opened app
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('🔔 Message opened from background: ${message.messageId}');
    _notificationTapStream.add({
      'type': 'fcm',
      'data': message.data,
      'notification': message.notification,
    });
  }

  /// Request notification permissions (iOS)
  Future<bool?> requestPermissions() async {
    return await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('📱 Local notification tapped: ${response.id}');
    _notificationTapStream.add({
      'type': 'local',
      'id': response.id,
      'payload': response.payload,
    });
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tasks_channel',
            'Task Notifications',
            channelDescription: 'Notifications for task reminders and updates',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print('✅ Notification scheduled: $id - $title');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      print('✅ Notification cancelled: $id');
    } catch (e) {
      print('❌ Error cancelling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      print('✅ All notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling all notifications: $e');
    }
  }

  /// Show instant notification
  Future<void> showInstantNotification({
    required String title,
    required String body,
    int id = 0,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'tasks_channel',
            'Task Notifications',
            channelDescription: 'Notifications for task reminders and updates',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload != null ? payload.toString() : null,
      );
      print('✅ Instant notification shown: $title');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Dispose streams
  void dispose() {
    _notificationTapStream.close();
    _messageReceivedStream.close();
  }
}
