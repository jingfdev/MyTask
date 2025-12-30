import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/local_task_service.dart';

class UserViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;

  UserViewModel() {
    // 🔑 Always stay in sync with FirebaseAuth
    _auth.authStateChanges().listen((firebaseUser) {
      user = firebaseUser;
      notifyListeners();
    });
  }

  // 🔔 SAVE FCM TOKEN
  Future<void> saveFcmToken(String token) async {
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user!.uid).set(
        {
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// 🟡 ENSURE GUEST USER (ANONYMOUS)
  Future<void> ensureGuestUser() async {
    if (_auth.currentUser == null) {
      final result = await _auth.signInAnonymously();
      user = result.user;
    }

    if (user == null) return;

    await _firestore.collection('users').doc(user!.uid).set(
      {
        'isGuest': user!.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    notifyListeners();
  }

  /// 🔵 MIGRATE GUEST TASKS → FIRESTORE (STEP 4)
  Future<void> migrateGuestTasksToFirestore() async {
    if (user == null || user!.isAnonymous) return;

    final localService = LocalTaskService();
    final guestTasks = await localService.loadTasks();

    if (guestTasks.isEmpty) return;

    final batch = _firestore.batch();
    final tasksRef =
    _firestore.collection('users').doc(user!.uid).collection('tasks');

    for (final task in guestTasks) {
      final docRef = tasksRef.doc();
      batch.set(docRef, task.toMap());
    }

    await batch.commit();
    await localService.saveTasks([]); // clear local tasks
  }

  /// 🔵 GOOGLE LOGIN (LINK IF GUEST)
  Future<void> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final current = _auth.currentUser;

    if (current != null && current.isAnonymous) {
      final result = await current.linkWithCredential(credential);
      await result.user!.reload();
      user = FirebaseAuth.instance.currentUser;
    } else {
      final result = await _auth.signInWithCredential(credential);
      user = result.user;
    }

    notifyListeners();
  }

    /// 🔁 SIGN OUT → BACK TO GUEST
  Future<void> signOut() async {
    await _auth.signOut();

    final result = await _auth.signInAnonymously();
    user = result.user;

    notifyListeners();
  }
}
