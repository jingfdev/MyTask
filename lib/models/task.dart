class Task {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? reminderTime;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
    this.dueDate,
    this.reminderTime,
  });

  /// Helper method for updating tasks
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminderTime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  /// 🔄 FROM MAP (Firestore + Local Safe)
  factory Task.fromMap(Map<String, dynamic> data, String id) {
    // ---- createdAt (safe)
    DateTime createdAt;
    final rawCreatedAt = data['createdAt'];

    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // ---- dueDate (safe & optional)
    DateTime? parsedDueDate;
    final rawDueDate = data['dueDate'];

    if (rawDueDate is String && rawDueDate.isNotEmpty) {
      parsedDueDate = DateTime.tryParse(rawDueDate);
    }

    // ---- reminderTime (safe & optional)
    DateTime? parsedReminderTime;
    final rawReminderTime = data['reminderTime'];

    if (rawReminderTime is String && rawReminderTime.isNotEmpty) {
      parsedReminderTime = DateTime.tryParse(rawReminderTime);
    }

    return Task(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: createdAt,
      dueDate: parsedDueDate,
      reminderTime: parsedReminderTime,
    );
  }

  /// 🔄 TO MAP (Firestore + Local)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
    };
  }
}
