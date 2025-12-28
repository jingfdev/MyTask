import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
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
  static const String _channelDescription = 'Notifications for task reminders and updates';

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

  Stream<Map<String, dynamic>> get notificationTapStream => _notificationTapStream.stream;
  Stream<RemoteMessage> get messageReceivedStream => _messageReceivedStream.stream;

  Future<void> initialize() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

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
    await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      final bool? isAllowed = await androidPlugin?.canScheduleExactNotifications();
      if (isAllowed == false) {
        await androidPlugin?.requestExactAlarmsPermission();
      }
    }
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _initializeFirebaseMessaging() async {
    String? token = await firebaseMessaging.getToken();
    if (token != null && onTokenGenerated != null) onTokenGenerated!(token);

    firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (onTokenGenerated != null) onTokenGenerated!(newToken);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      showInstantNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data,
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    _notificationTapStream.add({
      'type': 'fcm',
      'data': message.data,
    });
  }

  void _onNotificationTap(NotificationResponse response) {
    _handleNotificationNavigation(response.payload);
  }

  void _handleNotificationNavigation(String? payloadStr) {
    if (_navigatorKey == null || payloadStr == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(payloadStr);
      if (data.containsKey('route')) {
        _navigatorKey!.currentState?.pushNamed(data['route'] as String, arguments: data);
      } else if (data.containsKey('taskId')) {
        _navigatorKey!.currentState?.pushNamed('/tasks', arguments: data);
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
    }
  }

  /// --- UPDATED: Schedule based on task deadline and user settings ---
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime taskDueDate, // Input the actual task deadline
    String? payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if reminders are globally enabled
      final bool enabled = prefs.getBool('reminder_enabled') ?? true;
      if (!enabled) return;

      // 2. Fetch user's advance notice preference (default to 30 mins)
      final int advanceNotice = prefs.getInt('advance_notice_minutes') ?? 30;

      // 3. Calculate reminder time
      DateTime scheduledTime = taskDueDate.subtract(Duration(minutes: advanceNotice));

      // 4. SAFETY CATCH-UP: If time is in the past, notify in 5 seconds
      if (scheduledTime.isBefore(DateTime.now())) {
        debugPrint('⚠️ Intended reminder time was in the past. Triggering 5s catch-up.');
        scheduledTime = DateTime.now().add(const Duration(seconds: 5));
      }

      // 5. Android Exact Alarm Permission Check
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        final bool? canSchedule = await androidPlugin?.canScheduleExactNotifications();
        if (canSchedule == false) {
          debugPrint('⚠️ Exact alarms not permitted.');
          await androidPlugin?.requestExactAlarmsPermission();
          return;
        }
      }

      final bool sound = prefs.getBool('reminder_sound') ?? true;
      final bool vib = prefs.getBool('reminder_vibration') ?? true;
      final String dynamicId = await _getDynamicChannelId();

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
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
      );
      debugPrint('✅ Reminder set for $scheduledTime (Due: $taskDueDate)');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
    }
  }

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
        payload: payload != null ? jsonEncode(payload) : null,
      );
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async =>
      await flutterLocalNotificationsPlugin.cancel(id);

  void dispose() {
    _notificationTapStream.close();
    _messageReceivedStream.close();
  }
}