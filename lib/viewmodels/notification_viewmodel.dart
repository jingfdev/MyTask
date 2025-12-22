import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/notification.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

class NotificationViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  List<AppNotification> notifications = [];
  int unreadCount = 0;
  bool _isInitializing = false;

  NotificationViewModel() {
    _initialize();
  }

  /// Initialize notification listeners
  Future<void> _initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // Initialize the notification service FIRST
      await _notificationService.initialize();
      print('✅ Notification service initialized in view model');

      // Now set up listeners
      _notificationService.notificationTapStream.listen((notification) {
        _handleNotificationTap(notification);
      });

      _notificationService.messageReceivedStream.listen((message) {
        print('📬 New FCM message: ${message.messageId}');
      });
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Generate unique notification IDs
  int _generateId(String taskId, String type) {
    return taskId.hashCode ^ type.hashCode;
  }

  Future<bool> ensurePermissionGranted() async {
    try {
      final granted = await _notificationService.requestPermission();

      if (!granted) {
        debugPrint('❌ Notification permission NOT granted');
      } else {
        debugPrint('✅ Notification permission granted');
      }

      return granted;
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return false;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    print('Notification tapped: $notification');
    // This can be used to navigate to relevant task details
  }

  /// Create and save a notification
  Future<void> createNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? taskId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      const uuid = Uuid();
      final id = uuid.v4();

      final notification = AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        taskId: taskId,
        createdAt: DateTime.now(),
        isRead: false,
        payload: payload,
      );

      // Save to Firestore
      await _db
          .collection('notifications')
          .doc(id)
          .set(notification.toMap());

      print('✅ Notification created: $title');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  // ==================== IMMEDIATE NOTIFICATIONS ====================
  // These show notifications RIGHT NOW

  /// Send task created notification (IMMEDIATE)
  Future<void> sendTaskCreatedNotification(Task task) async {
    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    // Create in-app notification
    await createNotification(
      title: 'Task Created',
      body: 'New task: ${task.title}',
      type: NotificationType.taskCreated,
      taskId: task.id,
    );

    // Show local notification IMMEDIATELY
    await _notificationService.showInstantNotification(
      title: 'Task Created',
      body: task.title,
      payload: {'taskId': task.id, 'type': 'taskCreated'},
    );
  }

  /// Send task completed notification (IMMEDIATE)
  Future<void> sendTaskCompletedNotification(Task task) async {
    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    await createNotification(
      title: 'Task Completed',
      body: 'Great job! ${task.title} is completed.',
      type: NotificationType.taskCompleted,
      taskId: task.id,
    );

    await _notificationService.showInstantNotification(
      title: 'Task Completed',
      body: 'Great job! ${task.title}',
      payload: {'taskId': task.id, 'type': 'taskCompleted'},
    );
  }

  /// Send task updated notification (IMMEDIATE)
  Future<void> sendTaskUpdatedNotification(Task task) async {
    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    await createNotification(
      title: 'Task Updated',
      body: 'Task updated: ${task.title}',
      type: NotificationType.taskUpdated,
      taskId: task.id,
    );

    await _notificationService.showInstantNotification(
      title: 'Task Updated',
      body: task.title,
      payload: {'taskId': task.id, 'type': 'taskUpdated'},
    );
  }

  // ==================== SCHEDULED NOTIFICATIONS ====================
  // These schedule notifications for FUTURE times

  /// ✅ CORRECT: Schedule task due reminder notification
  Future<void> scheduleTaskDueReminder(Task task) async {
    if (task.dueDate == null) return;

    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    final notificationTime = task.dueDate!;

    // Only schedule if time is in the future
    if (notificationTime.isBefore(DateTime.now())) {
      print('⏰ Task due date is in the past, skipping: ${task.title}');
      return;
    }

    await createNotification(
      title: 'Task Due Reminder Scheduled',
      body: 'Reminder set for task: ${task.title}',
      type: NotificationType.taskDueReminder,
      taskId: task.id,
    );

    // ✅ SCHEDULE local notification for due date time
    await _notificationService.scheduleNotification(
      id: _generateId(task.id, 'due'),
      title: 'Task Due Now!',
      body: '${task.title} is due now',
      scheduledTime: notificationTime,
      payload: '{"taskId": "${task.id}", "type": "taskDueReminder"}',
    );

    print('⏰ Due reminder SCHEDULED for: ${task.title} at $notificationTime');
  }

  /// ✅ CORRECT: Schedule deadline approaching notification
  Future<void> scheduleTaskDeadlineNotification(Task task) async {
    if (task.dueDate == null) return;

    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    // Calculate time 24 hours before due date
    final deadlineApproachingTime = task.dueDate!.subtract(const Duration(hours: 24));
    final now = DateTime.now();

    // Only schedule if the time is in the future
    if (deadlineApproachingTime.isAfter(now)) {
      await createNotification(
        title: 'Deadline Approaching Scheduled',
        body: 'Deadline reminder set for: ${task.title}',
        type: NotificationType.taskDeadlineApproaching,
        taskId: task.id,
      );

      // ✅ SCHEDULE local notification for 24h before due date
      await _notificationService.scheduleNotification(
        id: _generateId(task.id, 'deadline'),
        title: 'Deadline Tomorrow!',
        body: '${task.title} is due tomorrow',
        scheduledTime: deadlineApproachingTime,
        payload: '{"taskId": "${task.id}", "type": "taskDeadlineApproaching"}',
      );

      print('📅 Deadline approaching notification SCHEDULED for: ${task.title} at $deadlineApproachingTime');
    } else {
      print('⏰ Deadline approaching time is in the past, skipping: ${task.title}');
    }
  }

  /// ✅ CORRECT: Schedule custom reminder notification
  Future<void> scheduleTaskReminderNotification(Task task) async {
    if (!task.hasReminder || task.reminderTime == null) return;

    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    final reminderTime = task.reminderTime!;
    final now = DateTime.now();

    // Only schedule if reminder is in the future
    if (reminderTime.isAfter(now)) {
      await createNotification(
        title: 'Task Reminder Scheduled',
        body: 'Custom reminder set for: ${task.title}',
        type: NotificationType.taskReminder,
        taskId: task.id,
      );

      // Format time difference for notification body
      String timeInfo = '';
      if (task.dueDate != null) {
        final dueIn = task.dueDate!.difference(now);
        if (dueIn.inDays > 0) {
          timeInfo = 'Due in ${dueIn.inDays} day${dueIn.inDays == 1 ? '' : 's'}';
        } else if (dueIn.inHours > 0) {
          timeInfo = 'Due in ${dueIn.inHours} hour${dueIn.inHours == 1 ? '' : 's'}';
        } else if (dueIn.inMinutes > 0) {
          timeInfo = 'Due in ${dueIn.inMinutes} minute${dueIn.inMinutes == 1 ? '' : 's'}';
        }
      }

      // ✅ SCHEDULE local notification for custom reminder time
      await _notificationService.scheduleNotification(
        id: _generateId(task.id, 'reminder'),
        title: 'Task Reminder: ${task.title}',
        body: timeInfo.isNotEmpty ? '$timeInfo - ${task.title}' : 'Reminder: ${task.title}',
        scheduledTime: reminderTime,
        payload: '{"taskId": "${task.id}", "type": "taskReminder"}',
      );

      print('🔔 Custom reminder SCHEDULED for: ${task.title} at $reminderTime');
    } else {
      print('⏰ Reminder time is in the past, skipping: ${task.title}');
    }
  }

  /// Schedule all types of notifications for a task
  Future<void> scheduleAllTaskNotifications(Task task) async {
    // Schedule custom reminder if enabled
    if (task.hasReminder && task.reminderTime != null) {
      await scheduleTaskReminderNotification(task);
    }

    // Schedule due date notifications
    if (task.dueDate != null) {
      await scheduleTaskDueReminder(task);
      await scheduleTaskDeadlineNotification(task);
    }
  }

  /// Show immediate reminder notification (for when reminder time arrives)
  Future<void> sendTaskReminderNotification(Task task) async {
    // Check permission first
    final allowed = await ensurePermissionGranted();
    if (!allowed) return;

    await createNotification(
      title: 'Task Reminder',
      body: 'Reminder: ${task.title}',
      type: NotificationType.taskReminder,
      taskId: task.id,
    );

    await _notificationService.showInstantNotification(
      title: 'Task Reminder',
      body: 'Reminder: ${task.title}',
      payload: {'taskId': task.id, 'type': 'taskReminder'},
    );
  }

  /// Cancel all notifications for a task
  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      // Cancel all types of notifications using unique IDs
      await _notificationService.cancelNotification(_generateId(taskId, 'reminder'));
      await _notificationService.cancelNotification(_generateId(taskId, 'due'));
      await _notificationService.cancelNotification(_generateId(taskId, 'deadline'));

      print('✅ All notifications cancelled for task: $taskId');
    } catch (e) {
      print('❌ Error cancelling task notifications: $e');
    }
  }

  /// Fetch all notifications
  Future<void> fetchNotifications() async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .get();

      notifications = snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .toList();

      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('❌ Error fetching notifications: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });

      // Update local list
      final index =
      notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      for (var notification in notifications) {
        if (!notification.isRead) {
          await markAsRead(notification.id);
        }
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
      notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      for (var notification in notifications) {
        await _db.collection('notifications').doc(notification.id).delete();
      }
      notifications.clear();
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
    }
  }

  /// Update unread count
  void _updateUnreadCount() {
    unreadCount = notifications.where((n) => !n.isRead).length;
  }

  /// Get notifications by task
  List<AppNotification> getNotificationsByTask(String taskId) {
    return notifications.where((n) => n.taskId == taskId).toList();
  }

  /// Get unread notifications
  List<AppNotification> getUnreadNotifications() {
    return notifications.where((n) => !n.isRead).toList();
  }

  /// Check if notification service is initialized
  Future<bool> isServiceInitialized() async {
    try {
      // Try to get FCM token as a way to check if service is ready
      await _notificationService.ensureInitialized();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Debug: Get all pending notifications
  Future<void> debugPendingNotifications() async {
    try {
      final pending = await _notificationService.getPendingNotifications();
      print('📋 Total pending notifications: ${pending.length}');

      for (var notif in pending) {
        print('  📝 ID: ${notif.id} | Title: "${notif.title}" | Body: "${notif.body}"');
      }
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
    }
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}