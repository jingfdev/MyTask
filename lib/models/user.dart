class User {
  final String id;
  final String email;
  final String? fullName;
  final bool darkMode;
  final bool notificationsEnabled;

  User({
    required this.id,
    required this.email,
    this.fullName,
    this.darkMode = false,
    this.notificationsEnabled = true,
  });

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    bool? darkMode,
    bool? notificationsEnabled,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
