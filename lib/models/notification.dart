class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? taskId;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? payload;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.taskId,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.payload,
  });

  /// Create AppNotification from Firestore document
  factory AppNotification.fromMap(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      taskId: data['taskId'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'info'),
        orElse: () => NotificationType.info,
      ),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      payload: data['payload'] as Map<String, dynamic>?,
    );
  }

  /// Convert AppNotification to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'taskId': taskId,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
    };
  }

  /// Create a copy with modified fields
  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? taskId,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }
}

enum NotificationType {
  taskCreated,
  taskDueReminder,
  taskCompleted,
  taskAssigned,
  taskUpdated,
  taskDeadlineApproaching,
  info,
}

