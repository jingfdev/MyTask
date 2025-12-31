import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    _auth.authStateChanges().listen((firebaseUser) async {
      user = firebaseUser;

      // ✅ Save user data to Firestore whenever auth state changes
      if (user != null) {
        await _saveUserToFirestore(user!);
      }

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

    // ✅ Save complete user data to Firestore
    await _saveUserToFirestore(user!);

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

  /// 🔵 GOOGLE LOGIN (LINK IF GUEST) - WITH WEB SUPPORT
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      debugPrint('❌ Error in Google sign in: $e');
      rethrow;
    }
  }

  /// Web-specific Google Sign-In
  Future<void> _signInWithGoogleWeb() async {
    try {
      // For web, use Firebase's built-in signInWithPopup
      final googleProvider = GoogleAuthProvider();

      // Add scopes
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Force account selection
      googleProvider.setCustomParameters({
        'prompt': 'select_account'
      });

      final current = _auth.currentUser;
      UserCredential userCredential;

      if (current != null && current.isAnonymous) {
        // Link with existing anonymous account
        userCredential = await current.linkWithPopup(googleProvider);
      } else {
        // Normal sign in
        userCredential = await _auth.signInWithPopup(googleProvider);
      }

      // Reload user data
      await userCredential.user!.reload();
      user = FirebaseAuth.instance.currentUser;

      // ✅ SAVE USER DATA TO FIRESTORE
      if (user != null) {
        await _saveUserToFirestore(user!);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Web Google sign in error: $e');

      // If popup fails, try redirect method
      if (e.toString().contains('popup') ||
          e.toString().contains('blocked')) {
        debugPrint('Popup blocked, trying redirect method...');
        await _signInWithGoogleWebRedirect();
      } else {
        rethrow;
      }
    }
  }

  /// Web alternative with redirect (for browsers that block popups)
  /// Web alternative with redirect (for browsers that block popups)
  Future<void> _signInWithGoogleWebRedirect() async {
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      final current = _auth.currentUser;

      if (current != null && current.isAnonymous) {
        // For linking anonymous account with Google
        await current.linkWithRedirect(googleProvider);
        // The actual linking happens after redirect
        // We need to check for the result when the page loads back
      } else {
        // Normal sign in with redirect
        await _auth.signInWithRedirect(googleProvider);
        // Sign in happens after redirect
      }

      // Note: After redirect, the page will reload
      // We need to check for the redirect result in the main app initialization
      // or in a separate method that gets called when the page loads

    } catch (e) {
      debugPrint('❌ Web redirect error: $e');
      rethrow;
    }
  }

  /// Method to check for redirect result after page loads
  Future<void> handleRedirectResult() async {
    try {
      final userCredential = await _auth.getRedirectResult();

      if (userCredential.user != null) {
        user = userCredential.user;

        // ✅ SAVE USER DATA TO FIRESTORE
        await _saveUserToFirestore(user!);

        notifyListeners();
        debugPrint('✅ Google Sign-In successful via redirect');
      }
    } catch (e) {
      debugPrint('❌ Error handling redirect result: $e');
    }
  }

  /// Mobile-specific Google Sign-In
  Future<void> _signInWithGoogleMobile() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final current = _auth.currentUser;
      UserCredential userCredential;

      if (current != null && current.isAnonymous) {
        userCredential = await current.linkWithCredential(credential);
      } else {
        userCredential = await _auth.signInWithCredential(credential);
      }

      // Reload user data
      await userCredential.user!.reload();
      user = FirebaseAuth.instance.currentUser;

      // ✅ SAVE USER DATA TO FIRESTORE
      if (user != null) {
        await _saveUserToFirestore(user!);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Mobile Google sign in error: $e');
      rethrow;
    }
  }

  /// 🔁 SIGN OUT → BACK TO GUEST
  Future<void> signSOut() async {
    // Sign out from Google if signed in
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('❌ Error signing out from Google: $e');
      }
    }

    // Sign out from Firebase
    await _auth.signOut();

    // Sign back in as anonymous user
    final result = await _auth.signInAnonymously();
    user = result.user;

    // ✅ Save guest user data to Firestore
    if (user != null) {
      await _saveUserToFirestore(user!);
    }

    notifyListeners();
  }

  /// 🔥 SAVE/UPDATE USER DATA TO FIRESTORE
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final usersCollection = _firestore.collection('users');
      final userDoc = usersCollection.doc(user.uid);

      // Check if document exists
      final docSnapshot = await userDoc.get();

      final userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'phoneNumber': user.phoneNumber,
        'isGuest': user.isAnonymous,
        'provider': user.providerData.isNotEmpty
            ? user.providerData.first.providerId
            : user.isAnonymous ? 'anonymous' : 'unknown',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Set createdAt only if document doesn't exist yet
      if (!docSnapshot.exists) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Use set with merge to update existing or create new
      await userDoc.set(userData, SetOptions(merge: true));

      debugPrint('✅ User data saved to Firestore: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error saving user to Firestore: $e');
      rethrow;
    }
  }

  /// 📱 GET USER DATA FROM FIRESTORE
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user data: $e');
      return null;
    }
  }

  /// ✏️ UPDATE USER PROFILE
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update Firebase Auth
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      // Reload user to get updated data
      await user.reload();

      // Update Firestore
      await _saveUserToFirestore(_auth.currentUser!);

      // Update local state
      this.user = _auth.currentUser;
      notifyListeners();

      debugPrint('✅ Profile updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// 🔄 CHECK IF USER IS SIGNED IN WITH GOOGLE
  bool isGoogleLinked() {
    return user != null &&
        user!.providerData.any((userInfo) => userInfo.providerId == 'google.com');
  }

  /// 📧 GET USER EMAIL (FROM FIRESTORE OR AUTH)
  Future<String?> getUserEmail() async {
    if (user == null) return null;

    // First try to get from Firestore (more reliable)
    final userData = await getUserData(user!.uid);
    if (userData != null && userData['email'] != null) {
      return userData['email'];
    }

    // Fallback to Firebase Auth
    return user!.email;
  }
}