import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart'; // ✅ THIS WAS MISSING

class TaskViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Task> tasks = [];

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

  /// Add a new task
  Future<void> addTask(Task task) async {
    await _db.collection('tasks').add(task.toMap());
    await fetchTasks();
  }

  /// Update existing task
  Future<void> updateTask(Task task) async {
    await _db.collection('tasks').doc(task.id).update(task.toMap());
    await fetchTasks();
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    await _db.collection('tasks').doc(id).delete();
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
}
