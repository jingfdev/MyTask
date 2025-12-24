import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mytask_project/viewmodels/notification_viewmodel.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/notification_badge.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/models/notification.dart';
import 'package:mytask_project/services/notification_service.dart';

/// Example Integration Guide - Copy code snippets into your screens

class ExampleIntegration {
  /// EXAMPLE 1: Add notification badge to AppBar
  static PreferredSizeWidget exampleAppBar(BuildContext context) {
    return AppBar(
      title: const Text('My Tasks'),
      elevation: 0,
      actions: [
        // Add this to show notification badge
        NotificationBadge(
          onPressed: () {
            Navigator.pushNamed(context, '/notifications');
          },
          child: const Icon(Icons.notifications),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// EXAMPLE 2: Navigate to notifications screen
  static void exampleNavigateToNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }

  /// EXAMPLE 3: Trigger manual notification
  static Future<void> exampleManualNotification(
    BuildContext context,
  ) async {
    final viewModel = context.read<NotificationViewModel>();
    
    await viewModel.createNotification(
      title: 'Custom Notification',
      body: 'This is a manual notification',
      type: NotificationType.info,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification sent!')),
    );
  }

  /// EXAMPLE 4: Create task with automatic notifications
  static Future<void> exampleCreateTaskWithNotifications(
    BuildContext context,
  ) async {
    final taskViewModel = context.read<TaskViewModel>();

    final task = Task(
      id: 'task_123',
      title: 'Complete Project',
      description: 'Finish the notification feature',
      isCompleted: false,
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 3)),
    );

    // This automatically sends notifications:
    // 1. "Task Created" notification
    // 2. "Task Due Reminder" (scheduled for due date)
    // 3. "Deadline Approaching" (scheduled for 24 hours before)
    await taskViewModel.addTask(task);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task created with notifications!')),
    );
  }

  /// EXAMPLE 5: Get unread notification count
  static Widget exampleUnreadCount(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, _) {
        return Text(
          'Unread: ${viewModel.unreadCount}',
          style: const TextStyle(fontSize: 16),
        );
      },
    );
  }

  /// EXAMPLE 6: Display list of unread notifications
  static Widget exampleUnreadList(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, _) {
        final unread = viewModel.getUnreadNotifications();

        return ListView.builder(
          itemCount: unread.length,
          itemBuilder: (context, index) {
            final notification = unread[index];
            return ListTile(
              title: Text(notification.title),
              subtitle: Text(notification.body),
              onTap: () {
                viewModel.markAsRead(notification.id);
              },
            );
          },
        );
      },
    );
  }

  /// EXAMPLE 7: Mark notification as read
  static Future<void> exampleMarkAsRead(
    BuildContext context,
    String notificationId,
  ) async {
    final viewModel = context.read<NotificationViewModel>();
    await viewModel.markAsRead(notificationId);
  }

  /// EXAMPLE 8: Delete notification
  static Future<void> exampleDeleteNotification(
    BuildContext context,
    String notificationId,
  ) async {
    final viewModel = context.read<NotificationViewModel>();
    await viewModel.deleteNotification(notificationId);
  }

  /// EXAMPLE 9: Listen to notification taps
  static void exampleListenToNotificationTaps(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This example shows how to handle notification taps
      // You might want to do this in a stateful widget's initState()
      
      // For FCM messages, listen in your main.dart or a service
      // NotificationService().notificationTapStream.listen((notification) {
      //   if (notification['type'] == 'local') {
      //     final payload = notification['payload'];
      //     // Navigate to task or perform action
      //   }
      // });
    });
  }

  /// EXAMPLE 10: Fetch and display notifications on screen load
  static void exampleFetchNotificationsOnLoad(BuildContext context) {
    // Use this in a widget's initState()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().fetchNotifications();
    });
  }

  /// EXAMPLE 11: Complete a task (sends completion notification)
  static Future<void> exampleCompleteTask(
    BuildContext context,
    Task task,
  ) async {
    final viewModel = context.read<TaskViewModel>();

    // This sends "Task Completed" notification automatically
    await viewModel.completeTask(task);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task completed!')),
    );
  }

  /// EXAMPLE 12: Update task (resend deadline notifications if date changed)
  static Future<void> exampleUpdateTask(
    BuildContext context,
    Task task,
  ) async {
    final viewModel = context.read<TaskViewModel>();

    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: 'Updated description',
      isCompleted: task.isCompleted,
      createdAt: task.createdAt,
      dueDate: DateTime.now().add(const Duration(days: 5)), // Changed due date
    );

    // This sends "Task Updated" notification
    // And re-schedules deadline reminders if due date changed
    await viewModel.updateTask(updatedTask);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task updated with new notifications!')),
    );
  }

  /// EXAMPLE 13: Get notifications for a specific task
  static void exampleGetTaskNotifications(
    BuildContext context,
    String taskId,
  ) {
    final viewModel = context.read<NotificationViewModel>();
    final taskNotifications = viewModel.getNotificationsByTask(taskId);

    print('Notifications for task $taskId: ${taskNotifications.length}');
    for (var notification in taskNotifications) {
      print('  - ${notification.title}: ${notification.body}');
    }
  }

  /// EXAMPLE 14: Full screen implementation example
  static void exampleFullScreenImplementation(BuildContext context) {
    // Step 1: Fetch notifications on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().fetchNotifications();
    });

    // Step 2: Build your UI with notifications
    // Use Consumer<NotificationViewModel> to get real-time updates
    // Step 3: Handle user interactions (mark as read, delete, etc.)
  }

  /// EXAMPLE 15: Test notifications locally
  static Future<void> exampleTestNotifications(
    BuildContext context,
  ) async {
    final service = NotificationService();

    // Show instant notification
    await service.showInstantNotification(
      title: 'Test Notification',
      body: 'This is a test notification',
    );

    // Schedule a notification for 10 seconds from now
    await service.scheduleNotification(
      id: 1,
      title: 'Scheduled Test',
      body: 'This appears in 10 seconds',
      scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
    );
  }
}

// Import this file and use the examples:
// import 'example_integration.dart';

// Then in your widgets, you can do:
// ExampleIntegration.exampleAppBar(context)
// ExampleIntegration.exampleNavigateToNotifications(context)
// etc.

// ============================================================================
// COMMON PATTERNS
// ============================================================================

/// Pattern 1: Add notification badge to app bar
class PatternAppBar extends StatelessWidget {
  const PatternAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('My App'),
      actions: [
        NotificationBadge(
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          child: const Icon(Icons.notifications),
        ),
      ],
    );
  }
}

/// Pattern 2: Fetch notifications on screen load
class PatternFetchNotifications extends StatefulWidget {
  const PatternFetchNotifications({super.key});

  @override
  State<PatternFetchNotifications> createState() =>
      _PatternFetchNotificationsState();
}

class _PatternFetchNotificationsState extends State<PatternFetchNotifications> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Consumer<NotificationViewModel>(
          builder: (context, viewModel, _) {
            return Text('Unread: ${viewModel.unreadCount}');
          },
        ),
      ),
    );
  }
}

/// Pattern 3: Handle task creation with notifications
class PatternTaskCreation extends StatelessWidget {
  const PatternTaskCreation({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final task = Task(
          id: 'task_1',
          title: 'New Task',
          description: 'Task with due date',
          isCompleted: false,
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 3)),
        );

        // Automatically sends notifications
        await context.read<TaskViewModel>().addTask(task);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created!')),
        );
      },
      child: const Text('Create Task with Notifications'),
    );
  }
}

/// Pattern 4: Display unread count badge
class PatternBadge extends StatelessWidget {
  const PatternBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, _) {
        return Badge(
          label: Text('${viewModel.unreadCount}'),
          child: const Icon(Icons.notifications),
        );
      },
    );
  }
}

