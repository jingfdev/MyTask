import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? user;
  String? _fcmToken;

  UserViewModel() {
    user = _auth.currentUser;
  }

  String? get fcmToken => _fcmToken;

  Future<void> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    user = result.user;
    notifyListeners();
  }

  Future<void> signOut() async {
    // Delete FCM token on sign out
    if (user != null && _fcmToken != null) {
      await _deleteFcmToken();
    }
    await _auth.signOut();
    user = null;
    _fcmToken = null;
    notifyListeners();
  }

  /// Save FCM token to Firestore for the current user
  Future<void> saveFcmToken(String token) async {
    try {
      _fcmToken = token;

      if (user == null) {
        print('⚠️ No user logged in, FCM token not saved: $token');
        return;
      }

      // Save token to Firestore under user's document
      await _firestore.collection('users').doc(user!.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved for user: ${user!.uid}');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Delete FCM token from Firestore
  Future<void> _deleteFcmToken() async {
    try {
      if (user == null) return;

      await _firestore.collection('users').doc(user!.uid).update({
        'fcmToken': FieldValue.delete(),
      });

      print('✅ FCM token deleted for user: ${user!.uid}');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }
}
