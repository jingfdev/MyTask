import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';
import '../services/notification_service.dart';
import 'notification_viewmodel.dart';

class TaskViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late NotificationViewModel _notificationViewModel;

  List<Task> tasks = [];

  TaskViewModel() {
    _notificationViewModel = NotificationViewModel();
  }

  /// Fetch all tasks
  Future<void> fetchTasks() async {
    final snapshot = await _db
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .get();

    tasks = snapshot.docs
        .map((doc) => Task.fromMap(doc.data(), doc.id))
        .toList();

    notifyListeners();
  }

  /// Add a new task with notification
  Future<void> addTask(Task task) async {
    await _db.collection('tasks').add(task.toMap());

    // Send notification for task creation
    await _notificationViewModel.sendTaskCreatedNotification(task);

    // Schedule deadline reminder if due date exists
    if (task.dueDate != null) {
      await _notificationViewModel.sendTaskDueReminder(task);
      await _notificationViewModel.sendDeadlineApproachingNotification(task);
    }

    await fetchTasks();
  }

  /// Update existing task with notification
  Future<void> updateTask(Task task) async {
    await _db.collection('tasks').doc(task.id).update(task.toMap());

    // Send notification for task update
    await _notificationViewModel.sendTaskUpdatedNotification(task);

    // Re-schedule notifications if due date changed
    await NotificationService().cancelNotification((task.id + '_deadline').hashCode);
    if (task.dueDate != null) {
      await _notificationViewModel.sendDeadlineApproachingNotification(task);
    }

    await fetchTasks();
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    await _db.collection('tasks').doc(id).delete();

    // Cancel associated notifications
    await NotificationService().cancelNotification(id.hashCode);
    await NotificationService().cancelNotification((id + '_deadline').hashCode);

    await fetchTasks();
  }

  /// Mark task as completed with notification
/// Toggle completion status (Complete/Undo)
  Future<void> toggleTaskCompletion(Task task) async {
    final newStatus = !task.isCompleted;
    
    await _db.collection('tasks').doc(task.id).update({
      'isCompleted': newStatus,
    });

    if (newStatus) {
      // Send notification only when marking as completed
      await _notificationViewModel.sendTaskCompletedNotification(task);
      // Cancel scheduled notifications
      await NotificationService().cancelNotification(task.id.hashCode);
      await NotificationService().cancelNotification((task.id + '_deadline').hashCode);
    }

    // Refresh the local list
    await fetchTasks();
  }

  /// Get tasks for a specific date (Calendar)
  Future<List<Task>> getTasksByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snapshot = await _db
        .collection('tasks')
        .where(
      'dueDate',
      isGreaterThanOrEqualTo: start.toIso8601String(),
    )
        .where(
      'dueDate',
      isLessThan: end.toIso8601String(),
    )
        .get();

    return snapshot.docs
        .map((doc) => Task.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  void dispose() {
    _notificationViewModel.dispose();
    super.dispose();
  }
}
