import 'package:flutter/material.dart';
import 'package:mytask_project/models/user.dart';
import 'package:mytask_project/services/supabase_service.dart';

class UserViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  /// Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize and check authentication status
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUser = _supabaseService.client.auth.currentUser;
      if (currentUser != null) {
        _user = User(
          id: currentUser.id,
          email: currentUser.email ?? '',
          fullName: currentUser.userMetadata?['full_name'] as String?,
        );
        _isAuthenticated = true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign up
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
      );

      _user = User(
        id: response.user!.id,
        email: response.user!.email ?? '',
      );
      _isAuthenticated = true;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      _user = User(
        id: response.user!.id,
        email: response.user!.email ?? '',
      );
      _isAuthenticated = true;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabaseService.signOut();
      _user = null;
      _isAuthenticated = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user preferences
  Future<void> updatePreferences({
    bool? darkMode,
    bool? notificationsEnabled,
  }) async {
    if (_user == null) return;

    try {
      _user = _user!.copyWith(
        darkMode: darkMode ?? _user!.darkMode,
        notificationsEnabled:
            notificationsEnabled ?? _user!.notificationsEnabled,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
