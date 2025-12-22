import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderTime {
  none,
  atTime,
  fiveMinutes,
  tenMinutes,
  fifteenMinutes,
  thirtyMinutes,
  oneHour,
  twoHours,
  oneDay,
  custom,
}

class Task {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final ReminderTime? reminderType;
  final bool hasReminder;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
    this.dueDate,
    this.reminderTime,
    this.reminderType,
    this.hasReminder = false,
  });

  // Helper method for updating tasks in the ViewModel
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminderTime,
    ReminderTime? reminderType,
    bool? hasReminder,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderType: reminderType ?? this.reminderType,
      hasReminder: hasReminder ?? this.hasReminder,
    );
  }

  factory Task.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parsedDueDate;
    final rawDueDate = data['dueDate'];
    if (rawDueDate is String && rawDueDate.isNotEmpty) {
      parsedDueDate = DateTime.tryParse(rawDueDate);
    }

    DateTime? parsedReminderTime;
    final rawReminderTime = data['reminderTime'];
    if (rawReminderTime is String && rawReminderTime.isNotEmpty) {
      parsedReminderTime = DateTime.tryParse(rawReminderTime);
    }

    ReminderTime? parsedReminderType;
    final rawReminderType = data['reminderType'];
    if (rawReminderType != null) {
      if (rawReminderType is int && rawReminderType >= 0 && rawReminderType < ReminderTime.values.length) {
        parsedReminderType = ReminderTime.values[rawReminderType];
      } else if (rawReminderType is String) {
        try {
          parsedReminderType = ReminderTime.values.firstWhere(
                (e) => e.toString().split('.').last == rawReminderType,
          );
        } catch (e) {
          parsedReminderType = null;
        }
      }
    }

    return Task(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      dueDate: parsedDueDate,
      reminderTime: parsedReminderTime,
      reminderType: parsedReminderType,
      hasReminder: data['hasReminder'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'reminderType': reminderType?.index,
      'hasReminder': hasReminder,
    };
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, isCompleted: $isCompleted, dueDate: $dueDate, reminderTime: $reminderTime, hasReminder: $hasReminder)';
  }
}