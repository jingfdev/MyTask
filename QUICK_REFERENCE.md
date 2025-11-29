# ⚡ Quick Reference Guide

Fast lookup for implementing authentication and database features.

---

## 🔐 Authentication Quick Ref

### Sign In with Google
```dart
import 'package:mytask_project/services/supabase_service.dart';

// In your login button
try {
  await SupabaseService().signInWithGoogle();
} catch (e) {
  print('Error: $e');
}
```

### Check if User Logged In
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final user = Supabase.instance.client.auth.currentUser;
if (user != null) {
  print('User logged in: ${user.email}');
} else {
  print('Not logged in');
}
```

### Sign Out
```dart
await SupabaseService().signOut();
```

### Get User ID
```dart
final userId = SupabaseService().getCurrentUserId();
```

---

## 📝 Task Operations

### Create Task
```dart
final task = await SupabaseService().createTask(
  title: 'Buy groceries',
  description: 'Milk, eggs, bread',
  priority: 'high', // 'low', 'medium', 'high'
  dueDate: DateTime.now().add(Duration(days: 1)),
  category: 'Shopping',
);
```

### Get All Tasks
```dart
final tasks = await SupabaseService().fetchTasks();
// Returns: List<Task>
```

### Get Tasks by Date
```dart
final tasks = await SupabaseService().fetchTasksByDate(
  DateTime(2025, 11, 30),
);
```

### Update Task
```dart
final updatedTask = await SupabaseService().updateTask(
  id: 'task-uuid',
  title: 'Updated title',
  isCompleted: true,
  priority: 'low',
);
```

### Delete Task
```dart
await SupabaseService().deleteTask('task-uuid');
```

### Toggle Task Completion
```dart
await SupabaseService().toggleTaskCompletion('task-uuid', true);
```

---

## 🏷️ Category Operations

### Get All Categories
```dart
final categories = await SupabaseService().getCategories();
// Returns: List<Map<String, dynamic>>
```

### Create Category
```dart
final category = await SupabaseService().createCategory(
  name: 'Work',
  color: '#3498DB',
  icon: '💼',
);
```

### Delete Category
```dart
await SupabaseService().deleteCategory('category-uuid');
```

---

## ✅ Subtask Operations

### Create Subtask
```dart
final subtask = await SupabaseService().createSubtask(
  taskId: 'task-uuid',
  title: 'Buy milk',
  orderIndex: 0,
);
```

### Get Subtasks
```dart
final subtasks = await SupabaseService().getSubtasks('task-uuid');
```

### Mark Subtask Done
```dart
await SupabaseService().updateSubtaskCompletion('subtask-uuid', true);
```

### Delete Subtask
```dart
await SupabaseService().deleteSubtask('subtask-uuid');
```

---

## 👤 User Profile

### Get User Profile
```dart
final userProfile = await SupabaseService().getUserProfile();
// Returns: User?

print('Name: ${userProfile?.fullName}');
print('Email: ${userProfile?.email}');
print('Avatar: ${userProfile?.profileImageUrl}');
```

### Update User Settings
```dart
await SupabaseService().updateUserSettings(
  darkMode: true,
  notificationsEnabled: false,
);
```

---

## 🎨 UI Patterns

### Show Loading
```dart
if (isLoading) {
  return Center(child: CircularProgressIndicator());
}
```

### Show Error Message
```dart
if (error != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $error')),
  );
}
```

### Show Success Message
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Task created!'),
    backgroundColor: Colors.green,
  ),
);
```

### Guard Protected Routes
```dart
if (Supabase.instance.client.auth.currentUser == null) {
  Navigator.pushReplacementNamed(context, '/login');
}
```

---

## 📊 Task Properties

| Property | Type | Values |
|----------|------|--------|
| title | String | Any text |
| description | String? | Any text |
| priority | String | 'low', 'medium', 'high' |
| category | String | 'Personal', 'Work', 'Shopping', etc. |
| dueDate | DateTime? | Any date |
| isCompleted | bool | true/false |
| reminder_time | DateTime? | When to notify |
| recurrence | String? | 'none', 'daily', 'weekly', 'monthly' |

---

## 📊 User Properties

| Property | Type | Example |
|----------|------|---------|
| id | String | UUID from auth |
| email | String | user@gmail.com |
| fullName | String? | John Doe |
| profileImageUrl | String? | https://... |
| authProvider | String? | 'google' |
| darkMode | bool | false |
| notificationsEnabled | bool | true |
| createdAt | DateTime | 2025-11-29 |
| updatedAt | DateTime? | 2025-11-29 |

---

## 🔄 Common Workflows

### Complete Login Flow
```dart
// 1. Check if logged in
final user = Supabase.instance.client.auth.currentUser;

// 2. If not, show login screen
if (user == null) {
  return LoginScreen();
}

// 3. Load user profile
final profile = await SupabaseService().getUserProfile();

// 4. Show home screen
return HomePage();
```

### Add New Task Workflow
```dart
// 1. Get task data from form
final title = titleController.text;
final priority = selectedPriority;

// 2. Validate
if (title.isEmpty) {
  showError('Enter title');
  return;
}

// 3. Create
final task = await SupabaseService().createTask(
  title: title,
  priority: priority,
  category: selectedCategory,
);

// 4. Success
showSnackBar('Task created!');
Navigator.pop(context);
```

### Mark Task Done Workflow
```dart
// 1. Get task ID
final taskId = task.id;

// 2. Toggle completion
await SupabaseService().toggleTaskCompletion(taskId, true);

// 3. Refresh UI
setState(() {
  task.isCompleted = true;
});
```

---

## ⚠️ Error Handling Template

```dart
try {
  // Your code here
  final tasks = await SupabaseService().fetchTasks();
} on PostgrestException catch (e) {
  // Database error (row not found, etc)
  print('Database error: ${e.message}');
} on AuthException catch (e) {
  // Authentication error
  print('Auth error: ${e.message}');
} catch (e) {
  // Unknown error
  print('Error: $e');
}
```

---

## 🧪 Testing Checklist

Quick tests to verify functionality:

- [ ] Can sign in with Google
- [ ] User data appears in Supabase users table
- [ ] Can create a task
- [ ] Task appears in Supabase tasks table
- [ ] Task has correct user_id
- [ ] Can see only own tasks (RLS working)
- [ ] Can edit task
- [ ] Can delete task
- [ ] Can mark task as complete
- [ ] Can create category
- [ ] Can add subtasks
- [ ] Can sign out
- [ ] After logout, user can't access tasks
- [ ] User can sign back in
- [ ] Previously created tasks appear after re-login

---

## 📱 Mobile-Specific

### Android: Get SHA-1 Fingerprint
```bash
cd android
./gradlew signingReport
```

### iOS: Build for Testing
```bash
flutter build ios
```

---

## 🆘 Debugging

### Check Current User
```dart
final user = Supabase.instance.client.auth.currentUser;
debugPrint('Current user: ${user?.email}');
```

### View Supabase Logs
Dashboard → Logs (shows all database errors)

### Enable Supabase Verbose Logging
```dart
Supabase.initialize(...);
Supabase.instance.client.rest.trace = true;
```

### Print Task Data
```dart
final tasks = await SupabaseService().fetchTasks();
for (final task in tasks) {
  debugPrint('Task: ${task.title}, User: ${task.userId}');
}
```

---

## 📞 File Locations

| Feature | File |
|---------|------|
| Config | `lib/config/supabase_config.dart` |
| Auth & DB Methods | `lib/services/supabase_service.dart` |
| User Model | `lib/models/user.dart` |
| Task Model | `lib/models/task.dart` |
| DB Schema | `SUPABASE_SETUP.sql` |
| Setup Guide | `SETUP_GUIDE.md` |
| UI Examples | `UI_EXAMPLES.md` |

---

**Need more help?** Check `SETUP_GUIDE.md` or `UI_EXAMPLES.md`
