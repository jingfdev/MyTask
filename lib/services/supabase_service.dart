import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/models/user.dart' as app_user;

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

  /// Sign in with Google
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      throw Exception('Google sign in cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw 'No Access Token for Google Sign In.';
    }
    if (idToken == null) {
      throw 'No ID Token for Google Sign In.';
    }

    final response = await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    // Store user data in the database
    await _createOrUpdateUserProfile(
      userId: response.user!.id,
      email: response.user!.email!,
      fullName: googleUser.displayName,
      profileImageUrl: googleUser.photoUrl,
      authProvider: 'google',
    );

    return response;
  }

  /// Create or update user profile in database
  Future<void> _createOrUpdateUserProfile({
    required String userId,
    required String email,
    String? fullName,
    String? profileImageUrl,
    String? authProvider,
  }) async {
    await client.from('users').upsert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'profile_image_url': profileImageUrl,
      'auth_provider': authProvider,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get user profile from database
  Future<app_user.User?> getUserProfile() async {
    final userId = getCurrentUserId();
    if (userId == null) return null;

    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Update user profile settings
  Future<void> updateUserSettings({
    bool? darkMode,
    bool? notificationsEnabled,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    final updates = <String, dynamic>{};
    if (darkMode != null) updates['dark_mode'] = darkMode;
    if (notificationsEnabled != null) updates['notifications_enabled'] = notificationsEnabled;
    updates['updated_at'] = DateTime.now().toIso8601String();

    await client.from('users').update(updates).eq('id', userId);
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }
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

  // ==================== CATEGORY METHODS ====================

  /// Get all categories for current user
  Future<List<Map<String, dynamic>>> getCategories() async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    final response = await client
        .from('categories')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Create a new category
  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? color,
    String? icon,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    final response = await client.from('categories').insert({
      'user_id': userId,
      'name': name,
      'color': color ?? '#3498DB',
      'icon': icon ?? '📁',
    }).select();

    return response[0] as Map<String, dynamic>;
  }

  /// Delete a category
  Future<void> deleteCategory(String categoryId) async {
    await client.from('categories').delete().eq('id', categoryId);
  }

  // ==================== SUBTASK METHODS ====================

  /// Create a subtask
  Future<Map<String, dynamic>> createSubtask({
    required String taskId,
    required String title,
    int? orderIndex,
  }) async {
    final response = await client.from('subtasks').insert({
      'task_id': taskId,
      'title': title,
      'order_index': orderIndex ?? 0,
    }).select();

    return response[0] as Map<String, dynamic>;
  }

  /// Update subtask completion
  Future<void> updateSubtaskCompletion(String subtaskId, bool isCompleted) async {
    await client
        .from('subtasks')
        .update({'is_completed': isCompleted})
        .eq('id', subtaskId);
  }

  /// Get subtasks for a task
  Future<List<Map<String, dynamic>>> getSubtasks(String taskId) async {
    final response = await client
        .from('subtasks')
        .select()
        .eq('task_id', taskId)
        .order('order_index', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Delete a subtask
  Future<void> deleteSubtask(String subtaskId) async {
    await client.from('subtasks').delete().eq('id', subtaskId);
  }
}
