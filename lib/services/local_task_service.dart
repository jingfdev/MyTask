import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class LocalTaskService {
  static const _key = 'guest_tasks';

  /// 📥 LOAD TASKS
  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return [];

    final List decoded = jsonDecode(raw);

    return decoded.map((e) {
      final map = Map<String, dynamic>.from(e);

      // ✅ FORCE ID TO EXIST
      final id = map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

      return Task.fromMap(map, id);
    }).toList();
  }

  /// 💾 SAVE ALL TASKS (PRIVATE)
  Future<void> _saveAll(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = tasks.map((t) {
      final map = t.toMap();
      map['id'] = t.id; // ✅ STORE ID
      return map;
    }).toList();

    await prefs.setString(_key, jsonEncode(jsonList));
  }

  /// ➕ ADD TASK
  Future<void> addTask(Task task) async {
    final tasks = await loadTasks();
    tasks.insert(0, task);
    await _saveAll(tasks);
  }

  /// ✏️ UPDATE TASK
  Future<void> updateTask(Task task) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);

    if (index != -1) {
      tasks[index] = task;
      await _saveAll(tasks);
    }
  }

  /// 🗑 DELETE TASK
  Future<void> deleteTask(String id) async {
    final tasks = await loadTasks();
    tasks.removeWhere((t) => t.id == id);
    await _saveAll(tasks);
  }

  /// 🧹 CLEAR / OVERWRITE TASKS (USED AFTER GOOGLE LOGIN)
  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();

    if (tasks.isEmpty) {
      await prefs.remove(_key);
      return;
    }

    final jsonList = tasks.map((t) {
      final map = t.toMap();
      map['id'] = t.id;
      return map;
    }).toList();

    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
