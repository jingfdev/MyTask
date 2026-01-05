import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
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
      debugPrint('🔐 Starting Google Sign-In process...');

      // CRITICAL: Ensure we have an anonymous user before attempting to link
      debugPrint('👤 Checking current user state...');
      if (_auth.currentUser == null || !_auth.currentUser!.isAnonymous) {
        debugPrint('❌ Current user is null or not anonymous');
        debugPrint('🔄 Attempting to ensure guest user exists...');
        await ensureGuestUser();
        debugPrint('✅ Guest user ensured');
      } else {
        debugPrint('✅ User is already anonymous - ready to link');
      }

      if (kIsWeb) {
        debugPrint('🌐 Using web-based Google Sign-In');
        return await _signInWithGoogleWeb();
      } else {
        debugPrint('📱 Using mobile-based Google Sign-In');
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      debugPrint('❌ Error in Google sign in: $e');
      debugPrint('📍 Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Web-specific Google Sign-In
  Future<void> _signInWithGoogleWeb() async {
    try {
      final googleProvider = GoogleAuthProvider();

      // Scopes
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      // Force account chooser
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
      });

      final current = _auth.currentUser;
      UserCredential userCredential;

      try {
        // 🔗 Try linking if guest
        if (current != null && current.isAnonymous) {
          userCredential = await current.linkWithPopup(googleProvider);
        } else {
          userCredential = await _auth.signInWithPopup(googleProvider);
        }
      } on FirebaseAuthException catch (e) {
        // ✅ FIX: Google already linked to another user
        if (e.code == 'credential-already-in-use') {
          debugPrint(
              '⚠️ Google already linked, signing in instead of linking');
          userCredential = await _auth.signInWithPopup(googleProvider);
        } else {
          rethrow;
        }
      }

      // Reload & sync user
      await userCredential.user!.reload();
      user = _auth.currentUser;

      // Save to Firestore
      if (user != null) {
        await _saveUserToFirestore(user!);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Web Google sign-in failed: $e');

      // Popup blocked fallback
      if (e.toString().contains('popup') ||
          e.toString().contains('blocked')) {
        debugPrint('🔁 Popup blocked → using redirect');
        await _signInWithGoogleWebRedirect();
      } else {
        rethrow;
      }
    }
  }

  /// Web alternative with redirect (for browsers that block popups)
  Future<void> _signInWithGoogleWebRedirect() async {
    try {
      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      final current = _auth.currentUser;

      if (current != null && current.isAnonymous) {
        // For linking anonymous account with Google
        await current.linkWithRedirect(googleProvider);
      } else {
        // Normal sign in with redirect
        await _auth.signInWithRedirect(googleProvider);
      }
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
      debugPrint('🔐 Starting mobile Google Sign-In...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        // Web Client ID from google-services.json (client_type: 3)
        serverClientId: '240127573028-0tal3bqj46siv1lvp4j15n8383d0ut0r.apps.googleusercontent.com',
        scopes: [
          'email',
          'profile',
        ],
      );

      // Ensure we start fresh - disconnect any existing session
      try {
        if (await googleSignIn.isSignedIn()) {
          debugPrint('🔄 Already signed in to Google, disconnecting first...');
          await googleSignIn.disconnect();
        }
      } catch (e) {
        debugPrint('⚠️ Error checking/disconnecting Google: $e');
        // Continue anyway
      }

      debugPrint('📱 Triggering Google Sign-In dialog...');

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn();
      } on PlatformException catch (e) {
        debugPrint('❌ PlatformException during Google Sign-In: ${e.code} - ${e.message}');
        debugPrint('📍 Details: ${e.details}');

        if (e.code == 'sign_in_failed' || e.code == '10') {
          throw Exception(
            'Google Sign-In failed. Please ensure:\n'
            '1. Google Play Services is up to date\n'
            '2. A Google account is signed in on this device\n'
            '3. SHA-1 fingerprint is correctly configured'
          );
        } else if (e.code == 'network_error') {
          throw Exception('Network error. Please check your internet connection.');
        } else if (e.code == 'sign_in_canceled') {
          debugPrint('⚠️ User cancelled Google Sign-In');
          return;
        }
        throw Exception('Google Sign-In error: ${e.message ?? e.code}');
      } catch (signInError) {
        debugPrint('❌ Google Sign-In SDK error: $signInError');
        debugPrint('📍 Error type: ${signInError.runtimeType}');

        // Check for common configuration errors
        final errorString = signInError.toString().toLowerCase();
        if (errorString.contains('securityexception') ||
            errorString.contains('unknown calling package')) {
          throw Exception(
            'Google Play Services error. Please:\n'
            '1. Sign in to a Google account on this device\n'
            '2. Update Google Play Services\n'
            '3. Clear Google Play Services cache and try again'
          );
        }
        if (errorString.contains('apierror') ||
            errorString.contains('10:') ||
            errorString.contains('developer_error') ||
            errorString.contains('sign_in_failed')) {
          throw Exception(
            'Google Sign-In configuration error. Please ensure:\n'
            '1. SHA-1 fingerprint is added to Firebase Console\n'
            '2. google-services.json is up to date\n'
            '3. OAuth consent screen is configured'
          );
        }
        rethrow;
      }

      if (googleUser == null) {
        debugPrint('⚠️ User cancelled Google Sign-In');
        return;
      }

      debugPrint('✅ User selected: ${googleUser.email}');
      debugPrint('🔑 Getting authentication tokens...');

      final googleAuth = await googleUser.authentication;

      debugPrint('📋 Token check - Access Token: ${googleAuth.accessToken != null ? "✅ Present" : "❌ Null"}');
      debugPrint('📋 Token check - ID Token: ${googleAuth.idToken != null ? "✅ Present" : "❌ Null"}');

      if (googleAuth.accessToken == null) {
        throw Exception('Failed to get access token from Google');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken,
      );

      debugPrint('🔗 Linking/signing in with Firebase...');
      final current = _auth.currentUser;
      UserCredential userCredential;

      if (current != null && current.isAnonymous) {
        debugPrint('🔄 Linking anonymous account with Google credentials...');
        try {
          userCredential = await current.linkWithCredential(credential);
          debugPrint('✅ Account linked successfully');
        } on FirebaseAuthException catch (e) {
          debugPrint('⚠️ Linking failed with code: ${e.code}, message: ${e.message}');

          if (e.code == 'credential-already-in-use') {
            debugPrint('🔄 Credential already in use, signing in instead of linking...');
            userCredential = await _auth.signInWithCredential(credential);
            debugPrint('✅ Signed in with existing credential');
          } else if (e.code == 'provider-already-linked') {
            debugPrint('ℹ️ Provider already linked, refreshing user...');
            await current.reload();
            user = _auth.currentUser;
            if (user != null) {
              await _saveUserToFirestore(user!);
            }
            notifyListeners();
            return;
          } else {
            debugPrint('❌ Linking error: ${e.message}');
            rethrow;
          }
        }
      } else {
        debugPrint('🆕 Signing in with Google credentials...');
        userCredential = await _auth.signInWithCredential(credential);
        debugPrint('✅ Signed in successfully');
      }

      // Reload user data
      debugPrint('♻️ Reloading user data...');
      await userCredential.user!.reload();
      user = FirebaseAuth.instance.currentUser;

      debugPrint('👤 User ID: ${user?.uid}');
      debugPrint('📧 User Email: ${user?.email}');

      // ✅ SAVE USER DATA TO FIRESTORE
      if (user != null) {
        debugPrint('💾 Saving user data to Firestore...');
        await _saveUserToFirestore(user!);
        debugPrint('✅ User data saved to Firestore');
      }

      notifyListeners();
      debugPrint('✅ Google Sign-In completed successfully');
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException in mobile Google sign in: ${e.code} - ${e.message}');
      throw Exception('Google Sign-In failed: ${e.message ?? e.code}');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException in mobile Google sign in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Mobile Google sign in error: $e');
      debugPrint('📍 Error type: ${e.runtimeType}');

      // Convert unknown errors to user-friendly messages
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('securityexception') ||
          errorString.contains('unknown calling package')) {
        throw Exception(
          'Google Play Services error. Please sign in to a Google account on this device first.'
        );
      }
      rethrow;
    }
  }

  /// 🔁 SIGN OUT → BACK TO GUEST (FIXED METHOD NAME)
  Future<void> signOut() async {
    debugPrint('🔄 Starting sign out process...');

    // Sign out from Google if signed in
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
        debugPrint('✅ Signed out from Google');
      } catch (e) {
        debugPrint('❌ Error signing out from Google: $e');
      }
    }

    try {
      // Sign out from Firebase
      await _auth.signOut();
      debugPrint('✅ Signed out from Firebase');

      // Sign back in as anonymous user
      final result = await _auth.signInAnonymously();
      user = result.user;
      debugPrint('✅ Signed in as anonymous user: ${user?.uid}');

      // ✅ Save guest user data to Firestore
      if (user != null) {
        await _saveUserToFirestore(user!);
        debugPrint('✅ Guest user data saved to Firestore');
      }

      notifyListeners();
      debugPrint('✅ Sign out process completed successfully');
    } catch (e) {
      debugPrint('❌ Error during sign out process: $e');
      rethrow;
    }
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
      final userDoc = await _firestore.collection('users').doc(uid).get();

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