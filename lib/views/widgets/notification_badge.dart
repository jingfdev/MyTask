import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/notification_viewmodel.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, notificationViewModel, _) {
        return Stack(
          children: [
            IconButton(
              icon: child,
              onPressed: onPressed,
            ),
            if (notificationViewModel.unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    notificationViewModel.unreadCount > 99
                        ? '99+'
                        : '${notificationViewModel.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

