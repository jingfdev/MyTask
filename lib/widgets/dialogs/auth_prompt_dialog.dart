import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a dialog asking user to sign in or continue as guest
/// Returns true if user wants to sign in, false if they want to continue as guest
Future<bool> showAuthPromptDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Save Tasks Permanently?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'As a guest, tasks are stored locally only. Sign in to sync across devices and never lose your data.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false);
              },
              child: const Text('Continue as Guest'),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ) ??
      false;
}

