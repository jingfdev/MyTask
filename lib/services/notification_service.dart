// File: lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:typed_data';


class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late FirebaseMessaging firebaseMessaging;

  // Track if initialized
  bool _isInitialized = false;
  Completer<void>? _initializationCompleter;

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

  /// Initialize both local and push notifications (call this in main.dart)
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    _initializationCompleter = Completer<void>();

    try {
      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: false, // We'll request manually
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

      _isInitialized = true;
      _initializationCompleter!.complete();
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      _initializationCompleter!.completeError(e);
      print('❌ Error initializing NotificationService: $e');
      rethrow;
    }
  }

  /// Wait for initialization to complete
  Future<void> ensureInitialized() async {
    if (!_isInitialized && _initializationCompleter == null) {
      // Start initialization if not started
      return initialize();
    }

    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    return Future.value();
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Get FCM token
    String? token = await firebaseMessaging.getToken();
    print('🔑 FCM Token: $token');

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to background message (set up in main.dart)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Unified permission request for all platforms
  Future<bool> requestPermission() async {
    // Ensure we're initialized
    await ensureInitialized();

    bool allPermissionsGranted = true;

    // Handle Android 13+ permission
    final androidPermission = await _handleAndroidPermission();
    if (!androidPermission) {
      allPermissionsGranted = false;
    }

    // Handle iOS permission
    final iosPermission = await _handleIOSPermission();
    if (!iosPermission) {
      allPermissionsGranted = false;
    }

    // Handle FCM permission (separate from local)
    final fcmPermission = await _handleFCMPermission();
    if (!fcmPermission) {
      allPermissionsGranted = false;
    }

    if (allPermissionsGranted) {
      print('✅ All notification permissions granted');
    } else {
      print('⚠️ Some notification permissions not granted');
    }

    return allPermissionsGranted;
  }

  /// Handle Android 13+ notification permission - FIXED
  Future<bool> _handleAndroidPermission() async {
    try {
      // For Android 13+, we use FirebaseMessaging to request permission
      final settings = await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;

      // Also check local notification permission
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final canNotify = await androidPlugin.areNotificationsEnabled();
        print('📱 Android notifications enabled: $canNotify');
        return granted && (canNotify ?? false);
      }

      return granted;
    } catch (e) {
      print('❌ Error checking Android permission: $e');
      return false;
    }
  }

  /// Handle iOS permission
  Future<bool> _handleIOSPermission() async {
    try {
      final iosPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true; // For Android
    } catch (e) {
      print('❌ Error requesting iOS permission: $e');
      return false;
    }
  }

  /// Handle FCM permission
  Future<bool> _handleFCMPermission() async {
    try {
      final settings = await firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true, // Allow provisional for iOS
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print('❌ Error requesting FCM permission: $e');
      return false;
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    await ensureInitialized();
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

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('📱 Local notification tapped: ${response.id}');
    _notificationTapStream.add({
      'type': 'local',
      'id': response.id,
      'payload': response.payload,
    });
  }

  /// ✅ CRITICAL FIX: Schedule a notification - FIXED VERSION
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      await ensureInitialized();

      print('📅 SCHEDULING DEBUG:');
      print('   Current time: ${DateTime.now()}');
      print('   Scheduled for: $scheduledTime');
      print('   Time difference: ${scheduledTime.difference(DateTime.now())}');

      // ✅ CRITICAL FIX: Proper timezone conversion
      final tzScheduledTime = tz.TZDateTime.from(
        scheduledTime,
        tz.local, // Use local timezone
      );

      print('   TZ Scheduled: $tzScheduledTime');

      // Check if it's in the past
      if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        print('❌ WARNING: Cannot schedule notification in the past!');
        print('❌ Scheduled time: $tzScheduledTime');
        print('❌ Current time: ${tz.TZDateTime.now(tz.local)}');
        return;
      }

      // ✅ Create the notification channel FIRST (this was missing!)
      await _ensureNotificationChannel();

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        await _getNotificationDetails(),
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ Notification scheduled: $id - "$title" at $tzScheduledTime');
      print('✅ Will fire in: ${tzScheduledTime.difference(tz.TZDateTime.now(tz.local))}');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      print('❌ Stack trace: ${e.toString()}');
    }
  }

  /// ✅ ADDED: Ensure notification channel exists - FIXED (removed const)
  Future<void> _ensureNotificationChannel() async {
    // REMOVED const keyword here - AndroidNotificationChannel is not a const constructor
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'tasks_channel', // MUST match channel ID in NotificationDetails
      'Task Notifications',
      description: 'Notifications for task reminders and updates',
      importance: Importance.max, // MAX for heads-up notifications
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      ledColor: Colors.blue,
      showBadge: true,
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      print('📱 Notification channel ensured: ${channel.id}');
    }
  }

  /// ✅ ADDED: Get notification details with proper channel
  Future<NotificationDetails> _getNotificationDetails() async {
    await _ensureNotificationChannel();

    // Also removed const here for consistency
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'tasks_channel', // MUST match channel ID above
        'Task Notifications',
        channelDescription: 'Notifications for task reminders and updates',
        importance: Importance.max, // MAX for heads-up
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 500, 500]), // Custom pattern
        enableLights: true,
        ledColor: Colors.blue,
        ledOnMs: 1000,
        ledOffMs: 500,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        channelShowBadge: true,
        autoCancel: true,
        showWhen: true,
        colorized: true,
        color: Colors.blue,
        ticker: 'Task reminder',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      ),
    );
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    try {
      await ensureInitialized();
      await flutterLocalNotificationsPlugin.cancel(id);
      print('✅ Notification cancelled: $id');
    } catch (e) {
      print('❌ Error cancelling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await ensureInitialized();
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
      await ensureInitialized();

      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        await _getNotificationDetails(),
        payload: payload != null ? payload.toString() : null,
      );
      print('✅ Instant notification shown: $title');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Check if we have notification permission
  Future<bool> checkPermission() async {
    await ensureInitialized();

    // For Android, check if we can post notifications
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final canNotify = await androidPlugin.areNotificationsEnabled();
      return canNotify ?? false;
    }

    // For iOS, we'll just assume true since we requested earlier
    return true;
  }

  /// ✅ ADDED: Get all pending (scheduled) notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      await ensureInitialized();
      final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('📋 Found ${pending.length} pending notifications');
      return pending;
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  /// ✅ ADDED: Debug method to print all pending notifications
  Future<void> debugPrintPendingNotifications() async {
    try {
      final pending = await getPendingNotifications();
      print('=' * 50);
      print('📋 DEBUG: PENDING NOTIFICATIONS (${pending.length})');
      print('=' * 50);

      if (pending.isEmpty) {
        print('No pending notifications found.');
      } else {
        for (var i = 0; i < pending.length; i++) {
          final notif = pending[i];
          print('[${i + 1}] ID: ${notif.id}');
          print('    Title: "${notif.title}"');
          print('    Body: "${notif.body}"');
          print('    Payload: ${notif.payload}');
          print('---');
        }
      }
      print('=' * 50);
    } catch (e) {
      print('❌ Error debugging pending notifications: $e');
    }
  }

  /// ✅ ADDED: Diagnostic method to check scheduling
  Future<void> debugTaskScheduling(DateTime dueDate) async {
    print('🔍 TASK SCHEDULING DIAGNOSTIC:');
    print('   Due: $dueDate');

    // Calculate reminder time (5 minutes before)
    final reminderTime = dueDate.subtract(Duration(minutes: 5));
    print('   Reminder scheduled for: $reminderTime');
    print('   Current device time: ${DateTime.now()}');

    // Convert to timezone
    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);
    final tzNow = tz.TZDateTime.now(tz.local);

    print('   TZ Reminder: $tzReminderTime');
    print('   TZ Now: $tzNow');
    print('   Will fire in: ${tzReminderTime.difference(tzNow)}');

    if (tzReminderTime.isBefore(tzNow)) {
      print('❌ ERROR: Reminder is in the past!');
      print('❌ This notification will NEVER fire');
    } else {
      print('✅ Reminder is in the future - should work');
    }
  }

  /// ✅ ADDED: Test scheduling system
  Future<void> testSchedulingSystem() async {
    try {
      await ensureInitialized();

      print('🧪 Testing notification scheduling system...');

      // Test 1: Show immediate notification
      await showInstantNotification(
        title: 'Test Immediate',
        body: 'This should appear immediately',
        payload: {'test': 'immediate'},
      );

      // Test 2: Schedule notification for 2 minutes from now
      final twoMinutesLater = DateTime.now().add(Duration(minutes: 2));
      await scheduleNotification(
        id: 999999,
        title: 'Test Scheduled',
        body: 'This was scheduled for 2 minutes later',
        scheduledTime: twoMinutesLater,
        payload: '{"test": "scheduled", "time": "$twoMinutesLater"}',
      );

      print('✅ Test notifications created');
      await debugPrintPendingNotifications();
    } catch (e) {
      print('❌ Error testing scheduling system: $e');
    }
  }

  /// Dispose streams
  void dispose() {
    _notificationTapStream.close();
    _messageReceivedStream.close();
  }
}