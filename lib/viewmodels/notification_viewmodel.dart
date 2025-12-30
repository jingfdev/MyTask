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

  void _initialize() {
    _notificationService.notificationTapStream.listen((notification) {
      _handleNotificationTap(notification);
    });

    _notificationService.messageReceivedStream.listen((message) {
      debugPrint('📬 New FCM message: ${message.messageId}');
    });
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    debugPrint('Notification tapped: $notification');
  }

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

      await _db.collection('notifications').doc(id).set(notification.toMap());
    } catch (e) {
      debugPrint('❌ Error creating notification record: $e');
    }
  }

  Future<void> sendTaskCreatedNotification(Task task) async {
    await createNotification(
      title: 'Task Created',
      body: 'New task: ${task.title}',
      type: NotificationType.taskCreated,
      taskId: task.id,
    );

    await _notificationService.showInstantNotification(
      title: 'Task Created',
      body: task.title,
      payload: {'taskId': task.id, 'type': 'taskCreated'},
    );
  }

  Future<void> sendTaskDueReminder(Task task) async {
    if (task.dueDate == null) return;

    await _notificationService.scheduleNotification(
      id: task.id.hashCode,
      title: 'Upcoming Mission',
      body: 'Objective: ${task.title}',
      scheduledTime: task.dueDate!,
      payload: '{"taskId": "${task.id}", "type": "taskDueReminder"}',
    );
  }

  Future<void> sendTaskCompletedNotification(Task task) async {
    await createNotification(
      title: 'Task Completed',
      body: 'Great job! ${task.title} is completed.',
      type: NotificationType.taskCompleted,
      taskId: task.id,
    );

    await _notificationService.showInstantNotification(
      title: 'Objective Secured',
      body: 'Completed: ${task.title}',
      payload: {'taskId': task.id, 'type': 'taskCompleted'},
    );

    await _notificationService.cancelNotification(task.id.hashCode);
  }

  Future<void> sendTaskUpdatedNotification(Task task) async {
    if (task.dueDate != null && !task.isCompleted) {
      await _notificationService.scheduleNotification(
        id: task.id.hashCode,
        title: 'Objective Updated',
        body: 'New reminder for: ${task.title}',
        scheduledTime: task.dueDate!,
      );
    }
  }

  // --- Firestore & List Management ---

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

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({'isRead': true});
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        _updateUnreadCount();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error marking read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final WriteBatch batch = _db.batch();
      final unreadNotifications = notifications.where((n) => !n.isRead).toList();

      for (var n in unreadNotifications) {
        batch.update(_db.collection('notifications').doc(n.id), {'isRead': true});
      }

      await batch.commit();
      // Update local state instead of re-fetching for better performance
      for (int i = 0; i < notifications.length; i++) {
        notifications[i] = notifications[i].copyWith(isRead: true);
      }
      _updateUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error marking all read: $e');
    }
  }

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

  // --- ADDED THIS METHOD TO FIX YOUR ERROR ---
  Future<void> deleteAllNotifications() async {
    try {
      final WriteBatch batch = _db.batch();

      // Add all current notifications to the deletion batch
      for (var n in notifications) {
        batch.delete(_db.collection('notifications').doc(n.id));
      }

      await batch.commit();

      // Clear local list
      notifications.clear();
      _updateUnreadCount();
      notifyListeners();
      debugPrint('✅ All notifications deleted from Firestore');
    } catch (e) {
      debugPrint('❌ Error deleting all notifications: $e');
    }
  }

  void _updateUnreadCount() {
    unreadCount = notifications.where((n) => !n.isRead).length;
  }

  /// Get unread notifications
  List<AppNotification> getUnreadNotifications() {
    return notifications.where((n) => !n.isRead).toList();
  }

  /// Get notifications by task
  List<AppNotification> getNotificationsByTask(String taskId) {
    return notifications.where((n) => n.taskId == taskId).toList();
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
        payload: '{"taskId": "${task.id}", "type": "taskDeadlineApproaching"}',
      );

      debugPrint('✅ Deadline approaching notification scheduled for: ${task.title}');
    }
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}