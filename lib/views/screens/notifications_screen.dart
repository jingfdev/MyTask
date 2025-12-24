import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../viewmodels/notification_viewmodel.dart';
import '../../models/notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch notifications when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationViewModel>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          Consumer<NotificationViewModel>(
            builder: (context, notificationViewModel, _) {
              return notificationViewModel.notifications.isNotEmpty
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'mark_all_read') {
                          notificationViewModel.markAllAsRead();
                        } else if (value == 'delete_all') {
                          _showDeleteAllDialog(context);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'mark_all_read',
                          child: Text('Mark all as read'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete_all',
                          child: Text('Delete all'),
                        ),
                      ],
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationViewModel>(
        builder: (context, notificationViewModel, _) {
          if (notificationViewModel.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notificationViewModel.notifications.length,
            itemBuilder: (context, index) {
              final notification = notificationViewModel.notifications[index];
              return _buildNotificationTile(
                context,
                notification,
                notificationViewModel,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotification notification,
    NotificationViewModel viewModel,
  ) {
    return Dismissible(
      key: Key(notification.id),
      onDismissed: (_) {
        viewModel.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: notification.isRead ? Colors.white : Colors.blue[50],
        child: ListTile(
          onTap: () {
            if (!notification.isRead) {
              viewModel.markAsRead(notification.id);
            }
          },
          leading: _getNotificationIcon(notification.type),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(notification.body),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, yyyy h:mm a').format(notification.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: !notification.isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue[500],
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.taskCreated:
        iconData = Icons.add_circle;
        color = Colors.green;
        break;
      case NotificationType.taskDueReminder:
        iconData = Icons.alarm;
        color = Colors.orange;
        break;
      case NotificationType.taskCompleted:
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.taskAssigned:
        iconData = Icons.person_add;
        color = Colors.blue;
        break;
      case NotificationType.taskUpdated:
        iconData = Icons.edit;
        color = Colors.purple;
        break;
      case NotificationType.taskDeadlineApproaching:
        iconData = Icons.warning;
        color = Colors.red;
        break;
      default:
        iconData = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color),
    );
  }

  void _showDeleteAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<NotificationViewModel>().deleteAllNotifications();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

