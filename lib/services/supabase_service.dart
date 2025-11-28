import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mytask_project/models/task.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase (call this in main.dart)
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  /// Get current user email
  String? getCurrentUserEmail() {
    return client.auth.currentUser?.email;
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Fetch all tasks for current user
  Future<List<Task>> fetchTasks() async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    final response = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((task) => Task.fromJson(task as Map<String, dynamic>))
        .toList();
  }

  /// Fetch tasks for a specific date
  Future<List<Task>> fetchTasksByDate(DateTime date) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final response = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .gte('due_date', startOfDay.toIso8601String())
        .lt('due_date', endOfDay.toIso8601String())
        .order('due_date', ascending: true);

    return (response as List)
        .map((task) => Task.fromJson(task as Map<String, dynamic>))
        .toList();
  }

  /// Create a new task
  Future<Task> createTask({
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    required String category,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    final response = await client.from('tasks').insert({
      'user_id': userId,
      'title': title,
      'description': description,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': false,
      'category': category,
      'created_at': DateTime.now().toIso8601String(),
    }).select();

    return Task.fromJson(response[0] as Map<String, dynamic>);
  }

  /// Update a task
  Future<Task> updateTask({
    required String id,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    String? category,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (priority != null) updates['priority'] = priority;
    if (dueDate != null) updates['due_date'] = dueDate.toIso8601String();
    if (isCompleted != null) updates['is_completed'] = isCompleted;
    if (category != null) updates['category'] = category;

    final response = await client
        .from('tasks')
        .update(updates)
        .eq('id', id)
        .select();

    return Task.fromJson(response[0] as Map<String, dynamic>);
  }

  /// Delete a task
  Future<void> deleteTask(String id) async {
    await client.from('tasks').delete().eq('id', id);
  }

  /// Toggle task completion status
  Future<Task> toggleTaskCompletion(String id, bool newStatus) async {
    return updateTask(id: id, isCompleted: newStatus);
  }
}
