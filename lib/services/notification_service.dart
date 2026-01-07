import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late FirebaseMessaging firebaseMessaging;
  GlobalKey<NavigatorState>? _navigatorKey;

  final StreamController<Map<String, dynamic>> _notificationTapStream =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<RemoteMessage> _messageReceivedStream =
      StreamController<RemoteMessage>.broadcast();

  static const String _channelName = 'TaskMaster Notifications';
  static const String _channelDescription =
      'Notifications for task reminders and updates';

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    firebaseMessaging = FirebaseMessaging.instance;
  }

  Future<String> _getDynamicChannelId() async {
    final prefs = await SharedPreferences.getInstance();
    final bool sound = prefs.getBool('reminder_sound') ?? true;
    final bool vib = prefs.getBool('reminder_vibration') ?? true;
    return 'taskmaster_channel_s${sound ? 1 : 0}_v${vib ? 1 : 0}';
  }

  void Function(String token)? onTokenGenerated;

  Future<void> updateNotificationSettings() async {
    await _createNotificationChannel();
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Stream<Map<String, dynamic>> get notificationTapStream =>
      _notificationTapStream.stream;
  Stream<RemoteMessage> get messageReceivedStream =>
      _messageReceivedStream.stream;

  /// Initialize notifications
  /// This method sets up local and Firebase messaging
  Future<void> initialize() async {
    try {
      // Verify timezone is initialized before anything else
      if (tz.local.name == 'UTC' || tz.local.name.isEmpty) {
        debugPrint('⚠️ WARNING: Timezone may not be properly initialized!');
        debugPrint('   Current timezone: ${tz.local.name}');
        debugPrint('   This may prevent scheduled notifications from firing.');
      } else {
        debugPrint('✅ Timezone verified: ${tz.local.name}');
      }

      // Skip local notifications initialization on web (not supported)
      if (!kIsWeb) {
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
      }

      await _requestPermissions();
      await _createNotificationChannel();
      await _initializeFirebaseMessaging();

      final initialMessage = await firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationNavigation(
          initialMessage.data.isNotEmpty ? jsonEncode(initialMessage.data) : null,
        );
      }

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  Future<void> _requestPermissions() async {
    debugPrint('🔐 Requesting FCM permissions...');

    final NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      carPlay: false,
      criticalAlert: false,
      announcement: false,
    );

    debugPrint('📱 FCM Permission Status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ FCM permissions granted (Full Authorization)');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('⚠️ FCM permissions granted (Provisional)');
    } else {
      debugPrint('❌ FCM permissions denied');
    }

    if (Platform.isAndroid) {
      debugPrint('📱 Requesting Android-specific permissions...');
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Request notification permission
      final bool? notificationPermission = await androidPlugin?.requestNotificationsPermission();
      debugPrint('   Notification permission: ${notificationPermission ?? 'unknown'}');

      // Request exact alarm permission
      final bool? isAllowed =
          await androidPlugin?.canScheduleExactNotifications();
      debugPrint('   Can schedule exact notifications: $isAllowed');

      if (isAllowed == false) {
        debugPrint('⚠️ Requesting exact alarm permissions...');
        final bool? exactAlarmsGranted = await androidPlugin?.requestExactAlarmsPermission();
        debugPrint('   Exact alarms permission granted: $exactAlarmsGranted');
      }
    }

    debugPrint('✅ Permission request completed');
  }

  Future<void> _createNotificationChannel() async {
    final prefs = await SharedPreferences.getInstance();
    final bool playSound = prefs.getBool('reminder_sound') ?? true;
    final bool enableVib = prefs.getBool('reminder_vibration') ?? true;
    final String dynamicId = await _getDynamicChannelId();

    final androidChannel = AndroidNotificationChannel(
      dynamicId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: playSound,
      enableVibration: enableVib,
      sound: playSound ? null : const RawResourceAndroidNotificationSound(''),
      enableLights: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _initializeFirebaseMessaging() async {
    debugPrint('🚀 Initializing Firebase Cloud Messaging (FCM)...');

    try {
      // Get initial FCM token
      String? token = await firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('📱 ========== FCM TOKEN ==========');
        debugPrint('📱 $token');
        debugPrint('📱 ================================');
        if (onTokenGenerated != null) {
          onTokenGenerated!(token);
        }
      } else {
        debugPrint('⚠️ Failed to retrieve FCM token on initialization');
      }

      // Listen for token refresh
      debugPrint('🔄 Setting up FCM token refresh listener...');
      firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 ========== NEW FCM TOKEN ==========');
        debugPrint('🔄 $newToken');
        debugPrint('🔄 ====================================');
        if (onTokenGenerated != null) {
          onTokenGenerated!(newToken);
        }
      });

      // Listen for foreground messages
      debugPrint('👀 Setting up foreground message listener...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 ========== FOREGROUND MESSAGE ==========');
        debugPrint('📨 Message ID: ${message.messageId}');
        debugPrint('📨 Title: ${message.notification?.title}');
        debugPrint('📨 Body: ${message.notification?.body}');
        debugPrint('📨 Data: ${message.data}');
        debugPrint('📨 ========================================');
        _handleForegroundMessage(message);
      });

      // Listen for background/terminated message interactions
      debugPrint('🖥️ Setting up message opened app listener...');
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 ========== MESSAGE OPENED APP ==========');
        debugPrint('🔔 Message ID: ${message.messageId}');
        debugPrint('🔔 Title: ${message.notification?.title}');
        debugPrint('🔔 Body: ${message.notification?.body}');
        debugPrint('🔔 Data: ${message.data}');
        debugPrint('🔔 =========================================');
        _handleMessageOpenedApp(message);
      });

      debugPrint('✅ Firebase Cloud Messaging initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing Firebase Cloud Messaging: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Handling foreground message...');
    if (message.notification != null) {
      debugPrint('   📲 Notification title: ${message.notification!.title}');
      debugPrint('   📝 Notification body: ${message.notification!.body}');
      showInstantNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data,
      );
    } else {
      debugPrint('   ⚠️ No notification payload in foreground message');
    }
    _messageReceivedStream.add(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 Notification tapped from background/terminated state');
    debugPrint('   Message ID: ${message.messageId}');
    debugPrint('   Data: ${message.data}');
    _notificationTapStream.add({
      'type': 'fcm',
      'data': message.data,
    });
    // Also handle navigation if needed
    _handleNotificationNavigation(
      message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    _handleNotificationNavigation(response.payload);
  }

  void _handleNotificationNavigation(String? payloadStr) {
    if (_navigatorKey == null || payloadStr == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(payloadStr);
      if (data.containsKey('route')) {
        _navigatorKey!.currentState
            ?.pushNamed(data['route'] as String, arguments: data);
      } else if (data.containsKey('taskId')) {
        _navigatorKey!.currentState?.pushNamed('/tasks', arguments: data);
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    }
  }

  /// Schedule a notification at a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime, // The time to show the notification
    String? payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if reminders are globally enabled
      final bool enabled = prefs.getBool('reminder_enabled') ?? true;
      if (!enabled) {
        debugPrint('⚠️ Reminders disabled globally. Skipping notification.');
        return;
      }

      // 2. Validate the scheduled time
      DateTime finalScheduledTime = scheduledTime;
      final now = DateTime.now();

      if (scheduledTime.isBefore(now)) {
        debugPrint(
            '⚠️ Scheduled time ($scheduledTime) is in the past (now: $now). Using immediate notification.');
        finalScheduledTime = now.add(const Duration(seconds: 2));
      }

      // 3. Check Android permissions
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final bool? canSchedule =
            await androidPlugin?.canScheduleExactNotifications();
        if (canSchedule == false) {
          debugPrint('⚠️ Cannot schedule exact notifications. Falling back to inexact.');
        }
      }

      final bool sound = prefs.getBool('reminder_sound') ?? true;
      final bool vib = prefs.getBool('reminder_vibration') ?? true;
      final String dynamicId = await _getDynamicChannelId();

      debugPrint(
          '⏰ [NOTIFICATION SCHEDULING] ID: $id, Title: "$title", Body: "$body"');
      debugPrint('⏰ Scheduled for: $finalScheduledTime');
      debugPrint('⏰ Current time: $now');
      debugPrint('⏰ Time difference: ${finalScheduledTime.difference(now).inMinutes} minutes');

      // Ensure timezone is properly initialized
      if (tz.local.name == 'UTC') {
        debugPrint('⚠️ WARNING: Timezone is still UTC! This may prevent notifications from firing.');
      }

      final tzScheduledTime = tz.TZDateTime.from(finalScheduledTime, tz.local);
      debugPrint('⏰ TZDateTime: $tzScheduledTime (timezone: ${tz.local.name})');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            dynamicId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: vib,
            playSound: sound,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
      debugPrint('✅ Notification scheduled successfully for: $finalScheduledTime');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Show a notification immediately
  Future<void> showInstantNotification({
    required String title,
    required String body,
    int? id,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final String dynamicId = await _getDynamicChannelId();
      final prefs = await SharedPreferences.getInstance();
      final bool sound = prefs.getBool('reminder_sound') ?? true;
      final bool vib = prefs.getBool('reminder_vibration') ?? true;

      debugPrint('🔔 Showing instant notification...');
      debugPrint('   📲 Title: $title');
      debugPrint('   📝 Body: $body');
      debugPrint('   🎯 ID: ${id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000)}');
      debugPrint('   📦 Has payload: ${payload != null}');

      // Convert payload to JSON string for local notifications
      String? payloadString;
      if (payload != null) {
        payloadString = jsonEncode(payload);
      }

      await flutterLocalNotificationsPlugin.show(
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            dynamicId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: vib,
            playSound: sound,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payloadString,
      );
      debugPrint('✅ Instant notification displayed successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('🗑️ Notification $id cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling notification: $e');
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('🗑️ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  /// DEBUG: List all pending notifications
  Future<void> debugListPendingNotifications() async {
    try {
      final pendingNotifications = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      debugPrint('🔍 [DEBUG] Pending notifications count: ${pendingNotifications.length}');
      for (var notif in pendingNotifications) {
        debugPrint('  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
      }
    } catch (e) {
      debugPrint('❌ Error listing pending notifications: $e');
    }
  }

  /// Get current FCM token (useful for testing)
  Future<String?> getFcmToken() async {
    try {
      final token = await firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('📱 Current FCM Token: $token');
      } else {
        debugPrint('⚠️ No FCM token available');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error retrieving FCM token: $e');
      return null;
    }
  }

  void dispose() {
    _notificationTapStream.close();
    _messageReceivedStream.close();
  }
}
