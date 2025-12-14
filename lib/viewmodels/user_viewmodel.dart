import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;

  UserViewModel() {
    user = _auth.currentUser;
  }

  Future<void> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    user = result.user;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    user = null;
    notifyListeners();
  }
}
