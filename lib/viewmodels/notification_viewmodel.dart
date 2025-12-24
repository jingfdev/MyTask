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

  NotificationViewModel() {
    _initialize();
  }

  /// Initialize notification listeners
  void _initialize() {
    // Listen to notification taps
    _notificationService.notificationTapStream.listen((notification) {
      _handleNotificationTap(notification);
    });

    // Listen to incoming FCM messages
    _notificationService.messageReceivedStream.listen((message) {
      debugPrint('📬 New FCM message: ${message.messageId}');
    });
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> notification) {
    debugPrint('Notification tapped: $notification');
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

      debugPrint('✅ Notification created: $title');
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  /// Send task created notification
  Future<void> sendTaskCreatedNotification(Task task) async {
    // Create in-app notification
    await createNotification(
      title: 'Task Created',
      body: 'New task: ${task.title}',
      type: NotificationType.taskCreated,
      taskId: task.id,
    );

    // Show local notification
    await _notificationService.showInstantNotification(
      title: 'Task Created',
      body: task.title,
      payload: {'taskId': task.id, 'type': 'taskCreated'},
    );
  }

  /// Send task due date reminder notification
  Future<void> sendTaskDueReminder(Task task) async {
    if (task.dueDate == null) return;

    // Schedule notification for due date
    final notificationTime = task.dueDate!;

    await createNotification(
      title: 'Task Due Reminder',
      body: 'Task due: ${task.title}',
      type: NotificationType.taskDueReminder,
      taskId: task.id,
    );

    // Schedule local notification
    await _notificationService.scheduleNotification(
      id: task.id.hashCode,
      title: 'Task Due Reminder',
      body: task.title,
      scheduledTime: notificationTime,
      payload: '{"taskId": "${task.id}", "type": "taskDueReminder"}',
    );
  }

  /// Send deadline approaching notification (e.g., 24 hours before)
  Future<void> sendDeadlineApproachingNotification(Task task) async {
    if (task.dueDate == null) return;

    // Calculate time 24 hours before due date
    final deadlineApproachingTime =
        task.dueDate!.subtract(const Duration(hours: 24));

    // Only schedule if the time is in the future
    if (deadlineApproachingTime.isAfter(DateTime.now())) {
      await createNotification(
        title: 'Deadline Approaching',
        body: 'Task due tomorrow: ${task.title}',
        type: NotificationType.taskDeadlineApproaching,
        taskId: task.id,
      );

      // Schedule local notification
      await _notificationService.scheduleNotification(
        id: (task.id + '_deadline').hashCode,
        title: 'Deadline Approaching',
        body: 'Task due tomorrow: ${task.title}',
        scheduledTime: deadlineApproachingTime,
        payload:
            '{"taskId": "${task.id}", "type": "taskDeadlineApproaching"}',
      );

      debugPrint('✅ Deadline approaching notification scheduled for: ${task.title}');
    }
  }

  /// Send task completed notification
  Future<void> sendTaskCompletedNotification(Task task) async {
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

  /// Send task updated notification
  Future<void> sendTaskUpdatedNotification(Task task) async {
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
      debugPrint('❌ Error fetching notifications: $e');
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
      debugPrint('❌ Error marking notification as read: $e');
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
      debugPrint('❌ Error marking all as read: $e');
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
      debugPrint('❌ Error deleting notification: $e');
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
      debugPrint('❌ Error deleting all notifications: $e');
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

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}

