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
    try {
      final snapshot = await _db
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .get();

      tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();

      // Schedule notifications for all tasks with reminders
      await _scheduleTaskReminders();

      notifyListeners();
    } catch (e) {
      print('❌ Error fetching tasks: $e');
    }
  }

  /// Add a new task with notification
  Future<void> addTask(Task task) async {
    try {
      final docRef = await _db.collection('tasks').add(task.toMap());
      final taskWithId = task.copyWith(id: docRef.id);

      // ✅ IMMEDIATE notification for task creation
      await _notificationViewModel.sendTaskCreatedNotification(taskWithId);

      // ✅ SCHEDULE reminder notification if enabled
      if (task.hasReminder && task.reminderTime != null && task.reminderTime!.isAfter(DateTime.now())) {
        await _notificationViewModel.scheduleTaskReminderNotification(taskWithId);
      }

      // ✅ SCHEDULE due date notifications (these are now SCHEDULED, not immediate)
      if (task.dueDate != null) {
        // This schedules for the due date time
        await _notificationViewModel.scheduleTaskDueReminder(taskWithId);

        // This schedules for 24h before due date
        await _notificationViewModel.scheduleTaskDeadlineNotification(taskWithId);
      }

      await fetchTasks();
      print('✅ Task added: ${task.title}');
      print('⏰ Reminder scheduled: ${task.hasReminder}');
      print('📅 Due date scheduled: ${task.dueDate}');
    } catch (e) {
      print('❌ Error adding task: $e');
      rethrow;
    }
  }

  /// Update existing task with notification
  Future<void> updateTask(Task task) async {
    try {
      // Cancel existing notifications
      await _notificationViewModel.cancelTaskNotifications(task.id);

      // Update task in Firestore
      await _db.collection('tasks').doc(task.id).update(task.toMap());

      // ✅ IMMEDIATE notification for task update
      await _notificationViewModel.sendTaskUpdatedNotification(task);

      // ✅ SCHEDULE new reminder notification if enabled
      if (task.hasReminder && task.reminderTime != null && task.reminderTime!.isAfter(DateTime.now())) {
        await _notificationViewModel.scheduleTaskReminderNotification(task);
      }

      // ✅ SCHEDULE due date notifications
      if (task.dueDate != null) {
        await _notificationViewModel.scheduleTaskDueReminder(task);
        await _notificationViewModel.scheduleTaskDeadlineNotification(task);
      }

      await fetchTasks();
      print('✅ Task updated: ${task.title}');
    } catch (e) {
      print('❌ Error updating task: $e');
      rethrow;
    }
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    try {
      // Cancel all notifications for this task
      await _notificationViewModel.cancelTaskNotifications(id);

      // Delete from Firestore
      await _db.collection('tasks').doc(id).delete();

      await fetchTasks();
      print('✅ Task deleted: $id');
    } catch (e) {
      print('❌ Error deleting task: $e');
      rethrow;
    }
  }

  /// Toggle completion status (checkbox / undo)
  Future<void> toggleTaskCompletion(Task task) async {
    try {
      final newStatus = !task.isCompleted;
      final updatedTask = task.copyWith(isCompleted: newStatus);

      await _db.collection('tasks').doc(task.id).update({
        'isCompleted': newStatus,
      });

      if (newStatus) {
        // Task completed - IMMEDIATE notification
        await _notificationViewModel.sendTaskCompletedNotification(updatedTask);
        await _notificationViewModel.cancelTaskNotifications(task.id);
      } else {
        // Task uncompleted - reschedule notifications
        if (task.hasReminder && task.reminderTime != null && task.reminderTime!.isAfter(DateTime.now())) {
          await _notificationViewModel.scheduleTaskReminderNotification(updatedTask);
        }

        if (task.dueDate != null) {
          await _notificationViewModel.scheduleTaskDueReminder(updatedTask);
          await _notificationViewModel.scheduleTaskDeadlineNotification(updatedTask);
        }
      }

      await fetchTasks();
      print('✅ Task completion toggled: ${task.title} -> $newStatus');
    } catch (e) {
      print('❌ Error toggling task completion: $e');
      rethrow;
    }
  }

  /// ✅ COMPLETE TASK (used by notifications / examples)
  Future<void> completeTask(Task task) async {
    try {
      if (task.isCompleted) return;

      final completedTask = task.copyWith(isCompleted: true);

      await _db.collection('tasks').doc(task.id).update({'isCompleted': true});

      await _notificationViewModel.sendTaskCompletedNotification(completedTask);
      await _notificationViewModel.cancelTaskNotifications(task.id);

      await fetchTasks();
      print('✅ Task completed via notification: ${task.title}');
    } catch (e) {
      print('❌ Error completing task: $e');
      rethrow;
    }
  }

  /// Get tasks for a specific date (Calendar)
  Future<List<Task>> getTasksByDate(DateTime date) async {
    try {
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
    } catch (e) {
      print('❌ Error getting tasks by date: $e');
      return [];
    }
  }

  /// Schedule reminders for all tasks
  Future<void> _scheduleTaskReminders() async {
    print('🔄 Scheduling reminders for ${tasks.length} tasks...');
    for (final task in tasks) {
      if (task.hasReminder && task.reminderTime != null && !task.isCompleted) {
        print('  📝 Task "${task.title}" has reminder at ${task.reminderTime}');
        await _notificationViewModel.scheduleTaskReminderNotification(task);
      }
    }
  }

  /// Get tasks with upcoming reminders (for dashboard)
  List<Task> getUpcomingReminders() {
    final now = DateTime.now();
    final twoHoursFromNow = now.add(const Duration(hours: 2));

    return tasks.where((task) {
      return !task.isCompleted &&
          task.hasReminder &&
          task.reminderTime != null &&
          task.reminderTime!.isAfter(now) &&
          task.reminderTime!.isBefore(twoHoursFromNow);
    }).toList();
  }

  /// Get tasks due today
  List<Task> getTasksDueToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return tasks.where((task) {
      return !task.isCompleted &&
          task.dueDate != null &&
          task.dueDate!.isAfter(today) &&
          task.dueDate!.isBefore(tomorrow);
    }).toList();
  }

  /// Get overdue tasks
  List<Task> getOverdueTasks() {
    final now = DateTime.now();

    return tasks.where((task) {
      return !task.isCompleted &&
          task.dueDate != null &&
          task.dueDate!.isBefore(now);
    }).toList();
  }

  /// Get tasks with active reminders
  List<Task> getTasksWithReminders() {
    return tasks.where((task) {
      return !task.isCompleted && task.hasReminder && task.reminderTime != null;
    }).toList();
  }

  /// Get upcoming reminders count (next 24 hours)
  int getUpcomingRemindersCount() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return tasks.where((task) {
      return !task.isCompleted &&
          task.hasReminder &&
          task.reminderTime != null &&
          task.reminderTime!.isAfter(now) &&
          task.reminderTime!.isBefore(tomorrow);
    }).length;
  }


  @override
  void dispose() {
    _notificationViewModel.dispose();
    super.dispose();
  }
}