import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mytask_project/models/notification.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/notification_viewmodel.dart';

void main() {
  group('AppNotification', () {
    test('AppNotification.fromMap creates instance correctly', () {
      final data = {
        'title': 'Test Notification',
        'body': 'This is a test',
        'type': 'taskCreated',
        'taskId': 'task_123',
        'createdAt': '2024-12-20T10:00:00.000Z',
        'isRead': false,
      };

      final notification = AppNotification.fromMap(data, 'notif_1');

      expect(notification.id, 'notif_1');
      expect(notification.title, 'Test Notification');
      expect(notification.body, 'This is a test');
      expect(notification.type, NotificationType.taskCreated);
      expect(notification.taskId, 'task_123');
      expect(notification.isRead, false);
    });

    test('AppNotification.toMap converts to map correctly', () {
      final notification = AppNotification(
        id: 'notif_1',
        title: 'Test',
        body: 'Test body',
        type: NotificationType.taskCompleted,
        createdAt: DateTime(2024, 12, 20),
        isRead: true,
      );

      final map = notification.toMap();

      expect(map['title'], 'Test');
      expect(map['body'], 'Test body');
      expect(map['type'], 'taskCompleted');
      expect(map['isRead'], true);
    });

    test('AppNotification.copyWith creates copy with modified fields', () {
      final original = AppNotification(
        id: 'notif_1',
        title: 'Original',
        body: 'Original body',
        type: NotificationType.taskCreated,
        createdAt: DateTime.now(),
      );

      final copy = original.copyWith(
        title: 'Modified',
        isRead: true,
      );

      expect(copy.title, 'Modified');
      expect(copy.isRead, true);
      expect(copy.body, original.body);
      expect(copy.id, original.id);
    });
  });

  group('NotificationType', () {
    test('All notification types are defined', () {
      final types = [
        NotificationType.taskCreated,
        NotificationType.taskDueReminder,
        NotificationType.taskCompleted,
        NotificationType.taskAssigned,
        NotificationType.taskUpdated,
        NotificationType.taskDeadlineApproaching,
        NotificationType.taskReminder, // ADDED: New reminder type
        NotificationType.info,
      ];

      expect(types.length, 8); // Updated from 7 to 8
    });

    test('NotificationType.name returns correct enum name', () {
      expect(NotificationType.taskCreated.name, 'taskCreated');
      expect(NotificationType.taskDueReminder.name, 'taskDueReminder');
      expect(NotificationType.taskCompleted.name, 'taskCompleted');
      expect(NotificationType.taskReminder.name, 'taskReminder'); // ADDED
    });
  });

  group('NotificationViewModel', () {
    late NotificationViewModel viewModel;

    setUp(() {
      viewModel = NotificationViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Initial state has empty notifications', () {
      expect(viewModel.notifications, isEmpty);
      expect(viewModel.unreadCount, 0);
    });

    test('getUnreadNotifications returns only unread notifications', () {
      viewModel.notifications = [
        AppNotification(
          id: '1',
          title: 'Read',
          body: 'Body 1',
          type: NotificationType.taskCreated,
          createdAt: DateTime.now(),
          isRead: true,
        ),
        AppNotification(
          id: '2',
          title: 'Unread',
          body: 'Body 2',
          type: NotificationType.taskUpdated,
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];

      final unread = viewModel.getUnreadNotifications();
      expect(unread.length, 1);
      expect(unread[0].id, '2');
    });

    test('getNotificationsByTask returns notifications for specific task', () {
      viewModel.notifications = [
        AppNotification(
          id: '1',
          title: 'For Task 1',
          body: 'Body 1',
          type: NotificationType.taskCreated,
          taskId: 'task_1',
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: '2',
          title: 'For Task 2',
          body: 'Body 2',
          type: NotificationType.taskUpdated,
          taskId: 'task_2',
          createdAt: DateTime.now(),
        ),
      ];

      final forTask1 = viewModel.getNotificationsByTask('task_1');
      expect(forTask1.length, 1);
      expect(forTask1[0].taskId, 'task_1');
    });

    test('Deadline approaching notification is not scheduled if due date is in past',
            () async {
          final pastDate = DateTime.now().subtract(Duration(days: 1));
          final task = Task(
            id: 'task_1',
            title: 'Past Task',
            description: 'Already due',
            isCompleted: false,
            createdAt: DateTime.now(),
            dueDate: pastDate,
            reminderTime: null,
            reminderType: null,
            hasReminder: false,
          );

          // Should not throw error, just skip scheduling
          await viewModel.scheduleTaskDeadlineNotification(task); // FIXED: Changed method name
        });

    test('Reminder notification methods exist', () {
      // Test that the new methods are available
      final task = Task(
        id: 'task_1',
        title: 'Test Task',
        description: 'Test',
        isCompleted: false,
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(Duration(days: 1)),
        reminderTime: null,
        reminderType: null,
        hasReminder: false,
      );

      // These methods should exist (testing by calling them with a task that won't schedule)
      expect(() => viewModel.scheduleTaskDeadlineNotification(task), returnsNormally);
      expect(() => viewModel.scheduleTaskDueReminder(task), returnsNormally);
      expect(() => viewModel.scheduleTaskReminderNotification(task), returnsNormally);
    });

    test('Notification types match expected values', () {
      expect(NotificationType.values.length, 8); // Updated from 7 to 8
      expect(
        NotificationType.values,
        contains(NotificationType.taskDeadlineApproaching),
      );
      expect(
        NotificationType.values,
        contains(NotificationType.taskReminder), // ADDED: Check for new type
      );
    });
  });

  group('Notification Sorting', () {
    test('Notifications can be sorted by creation date', () {
      final notifications = [
        AppNotification(
          id: '1',
          title: 'First',
          body: 'Body',
          type: NotificationType.taskCreated,
          createdAt: DateTime(2024, 12, 20, 10, 0),
        ),
        AppNotification(
          id: '2',
          title: 'Third',
          body: 'Body',
          type: NotificationType.taskCreated,
          createdAt: DateTime(2024, 12, 20, 12, 0),
        ),
        AppNotification(
          id: '3',
          title: 'Second',
          body: 'Body',
          type: NotificationType.taskCreated,
          createdAt: DateTime(2024, 12, 20, 11, 0),
        ),
      ];

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(notifications[0].id, '2');
      expect(notifications[1].id, '3');
      expect(notifications[2].id, '1');
    });
  });

  group('Notification Filtering', () {
    test('Notifications can be filtered by type', () {
      final notifications = [
        AppNotification(
          id: '1',
          title: 'Created',
          body: 'Body',
          type: NotificationType.taskCreated,
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: '2',
          title: 'Completed',
          body: 'Body',
          type: NotificationType.taskCompleted,
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: '3',
          title: 'Updated',
          body: 'Body',
          type: NotificationType.taskUpdated,
          createdAt: DateTime.now(),
        ),
        AppNotification(
          id: '4',
          title: 'Reminder',
          body: 'Body',
          type: NotificationType.taskReminder, // ADDED: New reminder type
          createdAt: DateTime.now(),
        ),
      ];

      final completedNotifications = notifications
          .where((n) => n.type == NotificationType.taskCompleted)
          .toList();

      expect(completedNotifications.length, 1);
      expect(completedNotifications[0].id, '2');

      final reminderNotifications = notifications
          .where((n) => n.type == NotificationType.taskReminder) // NEW TEST
          .toList();

      expect(reminderNotifications.length, 1);
      expect(reminderNotifications[0].id, '4');
    });
  });

  group('Task with Reminders', () {
    test('Task model includes reminder fields', () {
      final task = Task(
        id: 'task_1',
        title: 'Task with Reminder',
        description: 'Test',
        isCompleted: false,
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(Duration(days: 1)),
        reminderTime: DateTime.now().add(Duration(hours: 12)),
        reminderType: ReminderTime.oneHour,
        hasReminder: true,
      );

      expect(task.hasReminder, true);
      expect(task.reminderTime, isNotNull);
      expect(task.reminderType, ReminderTime.oneHour);
    });

    test('Task without reminders has correct defaults', () {
      final task = Task(
        id: 'task_2',
        title: 'Task without Reminder',
        description: 'Test',
        isCompleted: false,
        createdAt: DateTime.now(),
        dueDate: null,
        reminderTime: null,
        reminderType: null,
        hasReminder: false,
      );

      expect(task.hasReminder, false);
      expect(task.reminderTime, isNull);
      expect(task.reminderType, isNull);
      expect(task.dueDate, isNull);
    });
  });
}