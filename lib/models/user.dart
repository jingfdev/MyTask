class User {
  final String id;
  final String email;
  final String? fullName;
  final String? profileImageUrl;
  final String? authProvider; // 'google', 'email', etc.
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool darkMode;
  final bool notificationsEnabled;

  User({
    required this.id,
    required this.email,
    this.fullName,
    this.profileImageUrl,
    this.authProvider,
    required this.createdAt,
    this.updatedAt,
    this.darkMode = false,
    this.notificationsEnabled = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      authProvider: json['auth_provider'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      darkMode: json['dark_mode'] as bool? ?? false,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'profile_image_url': profileImageUrl,
      'auth_provider': authProvider,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'dark_mode': darkMode,
      'notifications_enabled': notificationsEnabled,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? profileImageUrl,
    String? authProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? darkMode,
    bool? notificationsEnabled,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
