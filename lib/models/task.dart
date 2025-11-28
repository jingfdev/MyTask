class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String priority; // 'low', 'medium', 'high'
  final DateTime? dueDate;
  final bool isCompleted;
  final String category; // 'Personal', 'Work', etc.
  final DateTime createdAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.priority,
    this.dueDate,
    required this.isCompleted,
    required this.category,
    required this.createdAt,
  });

  /// Convert Task to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create Task from JSON (from Supabase)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      category: json['category'] as String? ?? 'Personal',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Create a copy of Task with some fields replaced
  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    bool? isCompleted,
    String? category,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
