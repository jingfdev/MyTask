import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late FirebaseMessaging firebaseMessaging;
  GlobalKey<NavigatorState>? _navigatorKey;

  // Stream controllers for notification events
  final StreamController<Map<String, dynamic>> _notificationTapStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<RemoteMessage> _messageReceivedStream =
      StreamController<RemoteMessage>.broadcast();

  // Channel constants
  static const String _channelId = 'taskmaster_channel';
  static const String _channelName = 'TaskMaster Notifications';
  static const String _channelDescription = 'Notifications for task reminders and updates';

  // Optional callback to persist token to backend
  void Function(String token)? onTokenGenerated;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    firebaseMessaging = FirebaseMessaging.instance;
  }

  /// Set navigator key for handling notification navigation
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Get stream for notification taps
  Stream<Map<String, dynamic>> get notificationTapStream =>
      _notificationTapStream.stream;

  /// Get stream for incoming FCM messages
  Stream<RemoteMessage> get messageReceivedStream =>
      _messageReceivedStream.stream;

  /// Initialize both local and push notifications
  Future<void> initialize() async {
    try {
      // Request notification permissions first
      await _requestPermissions();

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
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

      // Create Android notification channel
      await _createNotificationChannel();

      // Initialize Firebase Cloud Messaging
      await _initializeFirebaseMessaging();

      // Handle initial message when app launched from terminated state
      final initialMessage = await firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(
          initialMessage.data.isNotEmpty ? jsonEncode(initialMessage.data) : null,
        );
      }

      print('✅ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Error initializing NotificationService: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // Request permissions via FCM (works for both iOS and Android)
    await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
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
    if (token != null) {
      print('🔑 FCM Token: $token');
      if (onTokenGenerated != null) {
        onTokenGenerated!(token);
      }
    }

    // Listen for token refresh
    firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token refreshed: $newToken');
      if (onTokenGenerated != null) {
        onTokenGenerated!(newToken);
      }
    });

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to background message opened (app in background)
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
    _handleNotificationNavigation(response.payload);
  }

  /// Handle notification navigation
  void _handleNotificationNavigation(String? payloadStr) {
    if (_navigatorKey == null || payloadStr == null) return;

    try {
      final Map<String, dynamic> data = jsonDecode(payloadStr);

      // Navigate based on payload data
      if (data.containsKey('route')) {
        final route = data['route'] as String;
        _navigatorKey!.currentState?.pushNamed(route, arguments: data);
      } else if (data.containsKey('taskId')) {
        // Default to tasks screen if taskId is present
        _navigatorKey!.currentState?.pushNamed('/tasks', arguments: data);
      } else if (data.containsKey('type')) {
        // Handle different notification types
        switch (data['type']) {
          case 'task_reminder':
            _navigatorKey!.currentState?.pushNamed('/tasks', arguments: data);
            break;
          case 'task_assigned':
            _navigatorKey!.currentState?.pushNamed('/notifications', arguments: data);
            break;
          default:
            _navigatorKey!.currentState?.pushNamed('/notifications');
        }
      }
    } catch (e) {
      print('❌ Error parsing notification payload: $e');
    }
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
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
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
    int? id,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final notificationId = id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payloadStr = payload != null ? jsonEncode(payload) : null;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payloadStr,
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
