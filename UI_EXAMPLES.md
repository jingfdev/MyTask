# 📱 UI Implementation Examples

Code snippets for building the authentication and task management UI.

---

## 1. Login/Welcome Screen

```dart
import 'package:flutter/material.dart';
import 'package:mytask_project/services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      await SupabaseService().signInWithGoogle();
      
      // Navigate to home screen after successful login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'MyTask',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            SizedBox(height: 12),
            Text(
              'Organize your daily tasks',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _handleGoogleSignIn,
              icon: Image.asset(
                'assets/google_logo.png', // Add Google logo image
                width: 24,
              ),
              label: Text(
                isLoading ? 'Signing in...' : 'Sign in with Google',
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 2. Auth Guard / Wrapper Widget

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mytask_project/views/screens/login_screen.dart';
import 'package:mytask_project/views/screens/home_page.dart';

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Get current user
        final session = snapshot.data?.session;
        final user = session?.user;

        // If no user, show login screen
        if (user == null) {
          return LoginScreen();
        }

        // If user exists, show home screen
        return HomePage();
      },
    );
  }
}

// Use this in main.dart:
// runApp(MyApp());
// 
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: AuthWrapper(),
//     );
//   }
// }
```

---

## 3. Task Creation/Form Screen

```dart
import 'package:flutter/material.dart';
import 'package:mytask_project/services/supabase_service.dart';
import 'package:mytask_project/models/task.dart';

class TaskFormPage extends StatefulWidget {
  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPriority = 'medium';
  String _selectedCategory = 'Personal';
  DateTime? _selectedDueDate;
  bool _isLoading = false;

  Future<void> _createTask() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final task = await SupabaseService().createTask(
        title: _titleController.text,
        description: _descriptionController.text,
        priority: _selectedPriority,
        dueDate: _selectedDueDate,
        category: _selectedCategory,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task created successfully!')),
      );

      // Go back to home
      Navigator.of(context).pop(task);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Task')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  hintText: 'Enter task title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // Description field
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter task description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),

              // Priority dropdown
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: ['low', 'medium', 'high']
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedPriority = value ?? 'medium');
                },
              ),
              SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ['Personal', 'Work', 'Shopping', 'Health']
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value ?? 'Personal');
                },
              ),
              SizedBox(height: 16),

              // Due date picker
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDueDate == null
                          ? 'No due date'
                          : 'Due: ${_selectedDueDate!.toString().split(' ')[0]}',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _selectedDueDate = date);
                      }
                    },
                    child: Text('Pick Date'),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTask,
                  child: Text(_isLoading ? 'Creating...' : 'Create Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
```

---

## 4. Task List Display

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/models/task.dart';

class TaskListScreen extends StatefulWidget {
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  @override
  void initState() {
    super.initState();
    // Load tasks when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskViewModel>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Tasks')),
      body: Consumer<TaskViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (viewModel.tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tasks yet. Create one!'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: viewModel.tasks.length,
            itemBuilder: (context, index) {
              final task = viewModel.tasks[index];
              return TaskCard(task: task);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/task-form');
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) {
            context.read<TaskViewModel>().toggleTaskCompletion(
              task.id,
              value ?? false,
            );
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(task.category),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Text('Edit'),
              onTap: () {
                // Navigate to edit screen
              },
            ),
            PopupMenuItem(
              child: Text('Delete'),
              onTap: () {
                context.read<TaskViewModel>().deleteTask(task.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. Settings Screen with Logout

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mytask_project/services/supabase_service.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';

class SettingsPage extends StatelessWidget {
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService().signOut();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // User Info Section
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(currentUser?.email ?? 'User'),
            subtitle: Text('Google Account'),
          ),
          Divider(),

          // Preferences Section
          Padding(
            padding: EdgeInsets.only(left: 16, top: 16),
            child: Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
          ),
          
          Consumer<UserViewModel>(
            builder: (context, userViewModel, _) {
              return Column(
                children: [
                  SwitchListTile(
                    title: Text('Dark Mode'),
                    value: userViewModel.user?.darkMode ?? false,
                    onChanged: (value) {
                      userViewModel.updateUserSettings(darkMode: value);
                    },
                  ),
                  SwitchListTile(
                    title: Text('Notifications'),
                    value: userViewModel.user?.notificationsEnabled ?? true,
                    onChanged: (value) {
                      userViewModel.updateUserSettings(notificationsEnabled: value);
                    },
                  ),
                ],
              );
            },
          ),
          
          Divider(),

          // Logout Section
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. Update TaskViewModel to Fetch from Database

```dart
import 'package:flutter/foundation.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/services/supabase_service.dart';

class TaskViewModel extends ChangeNotifier {
  final _supabaseService = SupabaseService();

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _supabaseService.fetchTasks();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createTask({
    required String title,
    String? description,
    required String priority,
    DateTime? dueDate,
    required String category,
  }) async {
    try {
      final task = await _supabaseService.createTask(
        title: title,
        description: description,
        priority: priority,
        dueDate: dueDate,
        category: category,
      );
      _tasks.insert(0, task);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(String taskId, bool newStatus) async {
    try {
      await _supabaseService.toggleTaskCompletion(taskId, newStatus);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        // Refresh task from database
        await loadTasks();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _supabaseService.deleteTask(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
```

---

## 7. Update UserViewModel with Google Auth

```dart
import 'package:flutter/foundation.dart';
import 'package:mytask_project/models/user.dart' as app_user;
import 'package:mytask_project/services/supabase_service.dart';

class UserViewModel extends ChangeNotifier {
  final _supabaseService = SupabaseService();

  app_user.User? _user;
  bool _isLoading = false;

  app_user.User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> loadUserProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _supabaseService.getUserProfile();
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserSettings({
    bool? darkMode,
    bool? notificationsEnabled,
  }) async {
    try {
      await _supabaseService.updateUserSettings(
        darkMode: darkMode,
        notificationsEnabled: notificationsEnabled,
      );
      
      // Update local user object
      if (_user != null) {
        _user = _user!.copyWith(
          darkMode: darkMode ?? _user!.darkMode,
          notificationsEnabled: notificationsEnabled ?? _user!.notificationsEnabled,
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error updating settings: $e');
    }
  }
}
```

---

## 📌 Key Points

1. **Always check authentication** - Don't show tasks/forms if user not logged in
2. **Use ChangeNotifier** - Rebuild UI automatically when data changes
3. **Handle loading states** - Show spinners while fetching data
4. **Handle errors** - Show snackbars for failures
5. **Call ViewModel methods** - Don't call Supabase service directly from UI
6. **Use StreamBuilder** for auth state changes
7. **Cleanup** - Dispose controllers in `dispose()` method

---

Next: Implement these screens in your `views/screens/` folder!
