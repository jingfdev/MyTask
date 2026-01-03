import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../services/local_task_service.dart';
import '../services/notification_service.dart';
import 'notification_viewmodel.dart';

class TaskViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalTaskService _localService = LocalTaskService();

  late final NotificationViewModel _notificationViewModel;

  List<Task> tasks = [];

  TaskViewModel() {
    _notificationViewModel = NotificationViewModel();

    // ✅ Load tasks initially
    fetchTasks();

    // ✅ IMPORTANT: automatically switch storage mode when auth changes
    // This keeps your task list in sync when user signs in/out or links account.
    _auth.authStateChanges().listen((_) async {
      await fetchTasks();
    });
  }

  /// Guest means "anonymous user" OR "no user"
  bool get isGuest => _auth.currentUser == null || _auth.currentUser!.isAnonymous;

  String? get userId => _auth.currentUser?.uid;

  // ✅ RESTORED: Method to reschedule all reminders on app startup
  Future<void> rescheduleAllReminders() async {
    for (final task in tasks) {
      if (!task.isCompleted && task.dueDate != null) {
        await NotificationService().cancelNotification(task.id.hashCode);
        await _scheduleTaskReminder(task);
      }
    }
  }

  // --- PRIVATE HELPER FOR DYNAMIC REMINDERS ---
  Future<void> _scheduleTaskReminder(Task task) async {
    if (task.dueDate == null || task.isCompleted) return;

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

    // FIXED: Removed duplicate variable declaration here

    if (scheduledTime!.isAfter(DateTime.now())) {
      final payload = {
        'taskId': task.id,
        'taskTitle': task.title,
        'type': 'taskReminder',
      };

      await NotificationService().scheduleNotification(
        id: task.id.hashCode,
        title: 'Upcoming Task',
        body: bodyText,
        scheduledTime: scheduledTime,
        payload: jsonEncode(payload),
      );

      debugPrint('⏰ Notification scheduled for: $scheduledTime for task: ${task.title}');
    } else {
      debugPrint('⏰ Scheduled time is in the past, skipping notification for: ${task.title}');
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW: EXPLICIT LOCAL METHOD (guest-only)
  // Use this from TaskFormPage when user chooses "Continue as guest"
  // ---------------------------------------------------------------------------
  Future<void> addTaskLocal(Task task) async {
    // Save locally
    await _localService.addTask(task);

    // Schedule reminder based on local id
    await _scheduleTaskReminder(task);

    await fetchTasks();
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW: EXPLICIT FIRESTORE METHOD (logged-in only)
  // Use this from TaskFormPage after sign-in.
  // ---------------------------------------------------------------------------
  Future<void> addTaskToFirestore(Task task) async {
    if (userId == null) return;

    // Add to Firestore, get docId
    final docRef = await _db
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .add(task.toMap());

    final finalId = docRef.id;

    // Schedule reminder using Firestore id
    await _scheduleTaskReminder(task.copyWith(id: finalId));

    await fetchTasks();
  }

  // --- EXISTING METHODS (kept) ---

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

  /// KEEP: addTask still works, but now it's a "smart" method.
  /// - If guest: saves locally
  /// - If logged-in: saves to Firestore
  ///
  /// You can continue using addTask anywhere in the app.
  Future<void> addTask(Task task) async {
    String finalId = task.id;

    if (isGuest) {
      await _localService.addTask(task);
    } else {
      if (userId == null) return;

      final docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(task.toMap());

      finalId = docRef.id;
    }

    // Schedule reminder for the new task (ensure correct id)
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

      // NOTE: keeping your original query style
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