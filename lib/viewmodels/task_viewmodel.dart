import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/task.dart';
import '../services/local_task_service.dart';
import '../services/notification_service.dart';
import 'notification_viewmodel.dart';

class TaskViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalTaskService _localService = LocalTaskService();

  late NotificationViewModel _notificationViewModel;

  List<Task> tasks = [];

  TaskViewModel() {
    _notificationViewModel = NotificationViewModel();
    fetchTasks();
  }

  bool get isGuest => _auth.currentUser == null;
  String? get userId => _auth.currentUser?.uid;

  // --- NEW: PRIVATE HELPER FOR DYNAMIC REMINDERS ---

  // Inside TaskViewModel class
  Future<void> _scheduleTaskReminder(Task task) async {
    if (task.isCompleted) {
      debugPrint('⏰ Cannot schedule reminder: Task is completed');
      return;
    }

    // 1. Determine the time to schedule the notification
    DateTime? scheduledTime;
    String bodyText;

    if (task.reminderTime != null) {
      // User set a specific reminder time
      scheduledTime = task.reminderTime;
      bodyText = 'Reminder: ${task.title}';
      debugPrint('⏰ Using specific reminder time: $scheduledTime');
    } else if (task.dueDate != null) {
      // Fallback to "advance notice" logic if no specific reminder time is set
      final prefs = await SharedPreferences.getInstance();
      final int advanceMinutes = prefs.getInt('advance_notice_minutes') ?? 15;
      scheduledTime = task.dueDate!.subtract(Duration(minutes: advanceMinutes));
      bodyText = '${task.title} is due in $advanceMinutes minutes!';
      debugPrint('⏰ Using default advance notice ($advanceMinutes mins): $scheduledTime');
    } else {
      debugPrint('⏰ No due date or reminder time set. Skipping notification.');
      return;
    }

    // 2. Validate the scheduled time
    if (scheduledTime == null) return;

    // If the calculated time is in the past, but we have a due date that is in the future,
    // and we are using the "advance notice" logic (not explicit reminder time),
    // try to schedule it for the exact due date instead.
    if (scheduledTime.isBefore(DateTime.now()) &&
        task.reminderTime == null && // Only do this fallback for implicit reminders
        task.dueDate != null &&
        task.dueDate!.isAfter(DateTime.now())) {
      scheduledTime = task.dueDate!;
      bodyText = '${task.title} is due now!';
      debugPrint('⚠️ Advance reminder time passed. Scheduling for actual due date instead.');
    }

    // 3. Schedule the notification if the time is in the future
    if (scheduledTime.isAfter(DateTime.now())) {
      final payload = {
        'taskId': task.id,
        'taskTitle': task.title,
        'type': 'taskReminder',
      };

      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('⏰ [SCHEDULING TASK REMINDER]');
      debugPrint('Task ID: ${task.id}');
      debugPrint('Task Title: ${task.title}');
      debugPrint('Due Date: ${task.dueDate}');
      debugPrint('Reminder Time: ${task.reminderTime}');
      debugPrint('Final Scheduled Time: $scheduledTime');
      debugPrint('Current Time: ${DateTime.now()}');
      debugPrint('Time Until Reminder: ${scheduledTime.difference(DateTime.now()).inMinutes} minutes');
      debugPrint('═══════════════════════════════════════════════════');

      await NotificationService().scheduleNotification(
        id: task.id.hashCode,
        title: 'Upcoming Task',
        body: bodyText,
        scheduledTime: scheduledTime,
        payload: jsonEncode(payload),
      );
      debugPrint('✅ Notification scheduled successfully for task: ${task.title}');
    } else {
      debugPrint('⚠️ Scheduled time ($scheduledTime) is in the past. Skipping notification for: ${task.title}');
    }
  }
  // --- MODIFIED METHODS ---

  Future<void> fetchTasks() async {
    if (isGuest) {
      tasks = await _localService.loadTasks();
    } else {
      if (userId == null) return;
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .get();

      tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();
    }
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    String finalId = task.id;
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('📝 [ADDING NEW TASK]');
    debugPrint('Task: ${task.title}');
    debugPrint('Due Date: ${task.dueDate}');
    debugPrint('═══════════════════════════════════════════════════');

    if (isGuest) {
      await _localService.addTask(task);
    } else {
      final docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(task.toMap());
      finalId = docRef.id;
      debugPrint('✅ Task saved to Firestore with ID: $finalId');
    }

    // Schedule the reminder for the newly added task
    debugPrint('⏰ Now scheduling notification for task...');
    await _scheduleTaskReminder(task.copyWith(id: finalId));

    await fetchTasks();
  }

  Future<void> updateTask(Task task) async {
    if (isGuest) {
      await _localService.updateTask(task);
    } else {
      if (userId == null) return;
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(task.id)
          .update(task.toMap());

      await _notificationViewModel.sendTaskUpdatedNotification(task);
    }

    // Refresh Local Notifications: Cancel old and set new
    await NotificationService().cancelNotification(task.id.hashCode);
    if (!task.isCompleted) {
      await _scheduleTaskReminder(task);
    }

    await fetchTasks();
  }

  Future<void> deleteTask(String id) async {
    if (isGuest) {
      await _localService.deleteTask(id);
    } else {
      if (userId == null) return;
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(id)
          .delete();
    }

    // Stop any pending alerts for this deleted task
    await NotificationService().cancelNotification(id.hashCode);
    await fetchTasks();
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);

    if (isGuest) {
      await _localService.updateTask(updatedTask);
    } else {
      if (userId == null) return;
      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(task.id)
          .update({'isCompleted': updatedTask.isCompleted});

      if (updatedTask.isCompleted) {
        await _notificationViewModel.sendTaskCompletedNotification(task);
      }
    }

    // Manage Notifications based on completion
    if (updatedTask.isCompleted) {
      await NotificationService().cancelNotification(task.id.hashCode);
    } else {
      await _scheduleTaskReminder(updatedTask);
    }

    await fetchTasks();
  }

  // --- NEW: Method to reschedule all task reminders (e.g., on app startup) ---
  Future<void> rescheduleAllReminders() async {
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔄 [RESCHEDULING ALL TASK REMINDERS]');
    debugPrint('Total tasks to check: ${tasks.length}');
    debugPrint('═══════════════════════════════════════════════════');

    int scheduledCount = 0;
    int skippedCount = 0;

    for (final task in tasks) {
      if (!task.isCompleted && task.dueDate != null) {
        // Cancel any existing notification for this task first
        await NotificationService().cancelNotification(task.id.hashCode);

        // Then reschedule it
        await _scheduleTaskReminder(task);
        scheduledCount++;
      } else {
        skippedCount++;
      }
    }

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('✅ Rescheduling complete!');
    debugPrint('   Scheduled: $scheduledCount tasks');
    debugPrint('   Skipped: $skippedCount tasks (completed or no due date)');
    debugPrint('═══════════════════════════════════════════════════');
  }

  // ... (getTasksByDate remains same as your original)
  Future<List<Task>> getTasksByDate(DateTime date) async {
    if (isGuest) {
      final all = await _localService.loadTasks();
      return all.where((task) {
        if (task.dueDate == null) return false;
        return task.dueDate!.year == date.year &&
            task.dueDate!.month == date.month &&
            task.dueDate!.day == date.day;
      }).toList();
    } else {
      if (userId == null) return [];
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('dueDate', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('dueDate', isLessThan: end.toIso8601String())
          .get();

      return snapshot.docs
          .map((doc) => Task.fromMap(doc.data(), doc.id))
          .toList();
    }
  }

  @override
  void dispose() {
    _notificationViewModel.dispose();
    super.dispose();
  }
}
