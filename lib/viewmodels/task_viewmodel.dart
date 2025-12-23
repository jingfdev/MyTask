import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  bool get isGuest =>
      _auth.currentUser == null;


  String? get userId => _auth.currentUser?.uid;

  /// 🔄 FETCH TASKS
  Future<void> fetchTasks() async {
    if (isGuest) {
      // 🟡 Guest → Local storage
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

  /// ➕ ADD TASK
  Future<void> addTask(Task task) async {
    debugPrint('--- ADD TASK START ---');
    debugPrint('currentUser: ${_auth.currentUser}');
    debugPrint('uid: ${_auth.currentUser?.uid}');
    debugPrint('isAnonymous: ${_auth.currentUser?.isAnonymous}');
    debugPrint('isGuest: $isGuest');

    if (isGuest) {
      debugPrint('➡️ SAVING TO LOCAL STORAGE');
      await _localService.addTask(task);
    } else {
      debugPrint('➡️ SAVING TO FIRESTORE');

      await _db
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(task.toMap());
    }

    await fetchTasks();
    debugPrint('--- ADD TASK END ---');
  }

  /// ✏️ UPDATE TASK
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

      await NotificationService()
          .cancelNotification((task.id + '_deadline').hashCode);

      if (task.dueDate != null) {
        await _notificationViewModel.sendDeadlineApproachingNotification(task);
      }
    }

    await fetchTasks();
  }

  /// 🗑 DELETE TASK
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

      await NotificationService().cancelNotification(id.hashCode);
      await NotificationService()
          .cancelNotification((id + '_deadline').hashCode);
    }

    await fetchTasks();
  }

  /// ✅ TOGGLE COMPLETE
  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
    );

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
        await NotificationService().cancelNotification(task.id.hashCode);
        await NotificationService()
            .cancelNotification((task.id + '_deadline').hashCode);
      }
    }

    await fetchTasks();
  }

  /// 📅 CALENDAR TASKS
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
