import 'package:flutter/material.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/services/supabase_service.dart';
import 'package:mytask_project/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class TaskViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();

  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  bool _isLoading = false;
  String _filter = 'all'; // 'all', 'today', 'upcoming'
  String? _error;

  /// Getters
  List<Task> get tasks => _filteredTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filter => _filter;

  /// Initialize and fetch tasks
  Future<void> initialize() async {
    await fetchTasks();
  }

  /// Fetch all tasks from Supabase
  Future<void> fetchTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _supabaseService.fetchTasks();
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply filter to tasks
  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    switch (_filter) {
      case 'today':
        _filteredTasks = _tasks.where((task) {
          if (task.dueDate == null) return false;
          final dueDate = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
          return dueDate == today;
        }).toList();
        break;
      case 'upcoming':
        _filteredTasks = _tasks.where((task) {
          if (task.dueDate == null) return false;
          final dueDate = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );
          return dueDate.isAfter(today);
        }).toList();
        break;
      default:
        _filteredTasks = _tasks;
    }

    notifyListeners();
  }

  /// Set filter
  void setFilter(String filter) {
    _filter = filter;
    _applyFilter();
  }

  /// Get tasks for today
  List<Task> getTodayTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    return _tasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.isAfter(today) && task.dueDate!.isBefore(tomorrow);
    }).toList();
  }

  /// Get tasks for upcoming
  List<Task> getUpcomingTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _tasks.where((task) {
      if (task.dueDate == null) return false;
      final dueDate =
          DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      return dueDate.isAfter(today);
    }).toList();
  }

  /// Get tasks for a specific date (for calendar)
  Future<List<Task>> getTasksByDate(DateTime date) async {
    try {
      return await _supabaseService.fetchTasksByDate(date);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Create a new task
  Future<void> createTask({
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    required String category,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final task = await _supabaseService.createTask(
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        category: category,
      );

      _tasks.insert(0, task);

      // Schedule notification if due date is set
      if (dueDate != null) {
        final notificationTime = dueDate.subtract(Duration(minutes: 10));
        if (notificationTime.isAfter(DateTime.now())) {
          final notificationId =
              (task.id.hashCode).abs() % 100000; // Simple ID generation
          await _notificationService.scheduleNotification(
            id: notificationId,
            title: 'Task Due Soon!',
            body: 'Don\'t forget: ${task.title}',
            scheduledTime: notificationTime,
          );
        }
      }

      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update a task
  Future<void> updateTask({
    required String id,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    String? category,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedTask = await _supabaseService.updateTask(
        id: id,
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        isCompleted: isCompleted,
        category: category,
      );

      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }

      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.deleteTask(id);
      _tasks.removeWhere((t) => t.id == id);
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle task completion
  Future<void> toggleTaskCompletion(Task task) async {
    try {
      await updateTask(
        id: task.id,
        isCompleted: !task.isCompleted,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Search tasks by title or description
  void searchTasks(String query) {
    if (query.isEmpty) {
      _applyFilter();
    } else {
      _filteredTasks = _tasks
          .where((task) =>
              task.title.toLowerCase().contains(query.toLowerCase()) ||
              (task.description?.toLowerCase().contains(query.toLowerCase()) ??
                  false))
          .toList();
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
