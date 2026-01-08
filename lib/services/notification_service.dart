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
  bool _initialized = false;

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
  /// Safe to call multiple times - will only initialize once
  Future<void> initialize() async {
    // Prevent duplicate initialization
    if (_initialized) {
      debugPrint('ℹ️ NotificationService already initialized. Skipping.');
      return;
    }

    try {
      _initialized = true;

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
        try {
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

          await flutterLocalNotificationsPlugin
              .initialize(
                initializationSettings,
                onDidReceiveNotificationResponse: _onNotificationTap,
              )
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  debugPrint(
                      '⚠️ Local notifications initialization timed out');
                  return null;
                },
              );
        } catch (e) {
          debugPrint('⚠️ Error initializing local notifications: $e');
        }
      }

      // Request permissions with timeout
      try {
        await _requestPermissions().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Permission request timed out, continuing...');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Error requesting permissions: $e');
      }

      // Create notification channel
      try {
        await _createNotificationChannel().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ Notification channel creation timed out');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Error creating notification channel: $e');
      }

      // Initialize Firebase messaging
      try {
        await _initializeFirebaseMessaging().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Firebase messaging initialization timed out');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Error initializing Firebase messaging: $e');
      }

      // Handle initial message (non-blocking)
      try {
        final initialMessage = await firebaseMessaging
            .getInitialMessage()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (initialMessage != null) {
          _handleNotificationNavigation(
            initialMessage.data.isNotEmpty
                ? jsonEncode(initialMessage.data)
                : null,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error handling initial message: $e');
      }

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      _initialized = false;
      debugPrint('❌ Error initializing NotificationService: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _requestPermissions() async {
    debugPrint('🔐 Requesting FCM permissions...');

    try {
      // Request FCM permissions with timeout to prevent hanging
      try {
        final NotificationSettings settings =
            await firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          carPlay: false,
          criticalAlert: false,
          announcement: false,
        ).timeout(const Duration(seconds: 5));

        debugPrint('📱 FCM Permission Status: ${settings.authorizationStatus}');
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('✅ FCM permissions granted (Full Authorization)');
        } else if (settings.authorizationStatus ==
            AuthorizationStatus.provisional) {
          debugPrint('⚠️ FCM permissions granted (Provisional)');
        } else {
          debugPrint('⚠️ FCM permissions not determined or denied');
        }
      } on TimeoutException {
        debugPrint('⚠️ FCM permission request timed out, continuing...');
      }
    } catch (e) {
      debugPrint('⚠️ Error requesting FCM permissions: $e');
    }

    if (Platform.isAndroid) {
      try {
        debugPrint('📱 Requesting Android-specific permissions...');
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin == null) {
          debugPrint('⚠️ Android plugin not available');
          return;
        }

        // Request notification permission with timeout
        try {
          final bool? notificationPermission = await androidPlugin
              .requestNotificationsPermission()
              .timeout(const Duration(seconds: 3));
          debugPrint('   Notification permission: $notificationPermission');
        } on TimeoutException {
          debugPrint('   ⚠️ Notification permission request timed out');
        } catch (e) {
          debugPrint('   ⚠️ Error requesting notification permission: $e');
        }

        // Request exact alarm permission with timeout
        try {
          final bool? isAllowed = await androidPlugin
              .canScheduleExactNotifications()
              .timeout(const Duration(seconds: 3));
          debugPrint('   Can schedule exact notifications: $isAllowed');

          if (isAllowed == false) {
            debugPrint('⚠️ Requesting exact alarm permissions...');
            try {
              final bool? exactAlarmsGranted = await androidPlugin
                  .requestExactAlarmsPermission()
                  .timeout(const Duration(seconds: 3));
              debugPrint(
                  '   Exact alarms permission granted: $exactAlarmsGranted');
            } on TimeoutException {
              debugPrint('   ⚠️ Exact alarm permission request timed out');
            } catch (e) {
              debugPrint('   ⚠️ Error requesting exact alarms: $e');
            }
          }
        } on TimeoutException {
          debugPrint('   ⚠️ Exact notification check timed out');
        } catch (e) {
          debugPrint('   ⚠️ Error checking exact notification permissions: $e');
        }
      } catch (e) {
        debugPrint('⚠️ Error in Android permission flow: $e');
      }
    }

    debugPrint('✅ Permission request flow completed');
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
      // Get initial FCM token with timeout
      try {
        String? token =
            await firebaseMessaging.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ FCM token retrieval timed out');
            return null;
          },
        );
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
      } catch (e) {
        debugPrint('⚠️ Error getting FCM token: $e');
      }

      // Listen for token refresh
      debugPrint('🔄 Setting up FCM token refresh listener...');
      firebaseMessaging.onTokenRefresh.listen(
        (newToken) {
          try {
            debugPrint('🔄 ========== NEW FCM TOKEN ==========');
            debugPrint('🔄 $newToken');
            debugPrint('🔄 ====================================');
            if (onTokenGenerated != null) {
              onTokenGenerated!(newToken);
            }
          } catch (e) {
            debugPrint('⚠️ Error handling token refresh: $e');
          }
        },
        onError: (error) {
          debugPrint('⚠️ Error in token refresh stream: $error');
        },
        cancelOnError: false,
      );

      // Listen for foreground messages
      debugPrint('👀 Setting up foreground message listener...');
      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          try {
            debugPrint('📨 ========== FOREGROUND MESSAGE ==========');
            debugPrint('📨 Message ID: ${message.messageId}');
            debugPrint('📨 Title: ${message.notification?.title}');
            debugPrint('📨 Body: ${message.notification?.body}');
            debugPrint('📨 Data: ${message.data}');
            debugPrint('📨 ========================================');
            _handleForegroundMessage(message);
          } catch (e) {
            debugPrint('⚠️ Error handling foreground message: $e');
          }
        },
        onError: (error) {
          debugPrint('⚠️ Error in foreground message stream: $error');
        },
        cancelOnError: false,
      );

      // Listen for background/terminated message interactions
      debugPrint('🖥️ Setting up message opened app listener...');
      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          try {
            debugPrint('🔔 ========== MESSAGE OPENED APP ==========');
            debugPrint('🔔 Message ID: ${message.messageId}');
            debugPrint('🔔 Title: ${message.notification?.title}');
            debugPrint('🔔 Body: ${message.notification?.body}');
            debugPrint('🔔 Data: ${message.data}');
            debugPrint('🔔 =========================================');
            _handleMessageOpenedApp(message);
          } catch (e) {
            debugPrint('⚠️ Error handling message opened app: $e');
          }
        },
        onError: (error) {
          debugPrint('⚠️ Error in message opened app stream: $error');
        },
        cancelOnError: false,
      );

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
        final currentState = _navigatorKey?.currentState;
        if (currentState != null && currentState.mounted) {
          currentState.pushNamed(data['route'] as String, arguments: data);
        } else {
          debugPrint('⚠️ Navigator not available for navigation');
        }
      } else if (data.containsKey('taskId')) {
        final currentState = _navigatorKey?.currentState;
        if (currentState != null && currentState.mounted) {
          currentState.pushNamed('/tasks', arguments: data);
        } else {
          debugPrint('⚠️ Navigator not available for navigation');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Navigation error: $e');
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
