# 🔧 Supabase Setup Guide for MyTask

Complete step-by-step guide to set up your Supabase backend with Google authentication and database schema.

---

## 📋 Prerequisites

- Supabase account (free at [supabase.com](https://supabase.com))
- Google OAuth credentials (free at [Google Cloud Console](https://console.cloud.google.com))
- Your Supabase credentials from `lib/config/supabase_config.dart`

---

## 🚀 Step 1: Set Up Google OAuth in Supabase

### 1.1 Create OAuth App in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Navigate to **APIs & Services** > **Credentials**
4. Click **+ Create Credentials** > **OAuth client ID**
5. Choose **Application type: Web application**
6. Add Authorized redirect URIs:
   ```
   https://[YOUR-PROJECT-ID].supabase.co/auth/v1/callback
   ```
7. Copy your **Client ID** and **Client Secret**

### 1.2 Enable Google in Supabase

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Open your project
3. Navigate to **Authentication** > **Providers**
4. Find **Google** and click **Enable**
5. Paste your **Client ID** and **Client Secret** from Google Cloud Console
6. Save

---

## 📊 Step 2: Create Database Schema

### 2.1 Run SQL in Supabase

1. In Supabase Dashboard, go to **SQL Editor**
2. Click **+ New Query**
3. Copy all SQL from `SUPABASE_SETUP.sql` file in your project root
4. Paste into the editor
5. Click **Run**

✅ This creates:
- `users` table - Store user profiles
- `categories` table - Task categories
- `tasks` table - Main task items
- `subtasks` table - Breakdown tasks
- `task_tags` table - Tag system
- `task_attachments` table - File attachments
- **Row Level Security (RLS)** - Each user can only see their own data

### 2.2 Verify Tables Created

Go to **Database** > **Tables** and confirm you see:
- `users`
- `categories`
- `tasks`
- `subtasks`
- `task_tags`
- `task_attachments`

---

## 🔐 Step 3: Enable Google Sign-In in Android & iOS

### Android Setup

1. Open `android/app/build.gradle`
2. Verify `applicationId` matches your project
3. Get your SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
4. In Google Cloud Console > APIs & Services > Credentials
5. Edit your OAuth 2.0 Client ID (Android)
6. Add your SHA-1 fingerprint

### iOS Setup

1. Open `ios/Runner.xcodeproj` in Xcode
2. Note your **Bundle Identifier** (e.g., `com.example.mytask`)
3. In Google Cloud Console, create new OAuth 2.0 Client ID for iOS
4. Add your Bundle Identifier
5. Download and place the config file

---

## 📱 Step 4: Update Flutter App

Your app is already configured! The following is done:

✅ Added `google_sign_in` package to `pubspec.yaml`
✅ Created `lib/config/supabase_config.dart` with credentials
✅ Updated `lib/models/user.dart` with auth fields
✅ Added Google Sign-In to `lib/services/supabase_service.dart`
✅ Added methods:
  - `signInWithGoogle()` - Sign in with Google
  - `getUserProfile()` - Fetch user data
  - `updateUserSettings()` - Update preferences

### Run the app:

```bash
flutter pub get
flutter run
```

---

## 🎯 Step 5: Create UI for Authentication

You need to create a login screen. Here's the basic flow:

```dart
// In your login screen
import 'package:mytask_project/services/supabase_service.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await SupabaseService().signInWithGoogle();
          // Navigate to home screen
          Navigator.of(context).pushReplacementNamed('/home');
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login failed: $e')),
          );
        }
      },
      child: Text('Sign in with Google'),
    );
  }
}
```

---

## 📝 Database Schema Overview

### Users Table
```
id (UUID) - Primary key from auth
email (String) - User email
full_name (String) - User's full name
profile_image_url (String) - Avatar URL
auth_provider (String) - 'google', 'email', etc.
dark_mode (Boolean) - User preference
notifications_enabled (Boolean) - User preference
created_at (DateTime) - Account creation
updated_at (DateTime) - Last updated
```

### Tasks Table
```
id (UUID) - Task ID
user_id (UUID) - Owner of task
title (String) - Task title
description (String) - Task details
priority (String) - 'low', 'medium', 'high'
category (String) - Task category
is_completed (Boolean) - Done or not
due_date (DateTime) - When it's due
reminder_time (DateTime) - When to remind
recurrence (String) - 'none', 'daily', 'weekly', 'monthly'
created_at (DateTime)
updated_at (DateTime)
```

### Categories Table
```
id (UUID) - Category ID
user_id (UUID) - Owner
name (String) - Category name
color (String) - Hex color code
icon (String) - Emoji or icon
```

### Additional Tables
- **subtasks** - Break down large tasks
- **task_tags** - Tag system for organization
- **task_attachments** - Attach files to tasks

---

## 🔒 Security Features

✅ **Row Level Security (RLS)** enabled
- Users can ONLY see/edit their own data
- Each query automatically filters by `auth.uid()`

✅ **Automatic cascading deletes**
- Deleting user deletes all their tasks, categories, etc.

---

## 🚨 Common Issues & Fixes

### Issue: "Google Sign In cancelled"
**Solution:** User closed the Google sign-in dialog. Let them try again.

### Issue: "No user logged in" error
**Solution:** Check that user is authenticated before accessing tasks. Add auth check in your home screen.

### Issue: User data not appearing in database
**Solution:** 
1. Check RLS policies are enabled
2. Verify user is authenticated (`Supabase.instance.client.auth.currentUser`)
3. Check that `_createOrUpdateUserProfile()` is being called

### Issue: Google button not appearing
**Solution:**
- Ensure `google_sign_in` package is installed: `flutter pub get`
- Rebuild app: `flutter clean && flutter pub get && flutter run`

---

## ✨ Next Steps

1. ✅ Set up Google OAuth (Step 1)
2. ✅ Create database schema (Step 2)
3. ✅ Configure Android/iOS (Step 3)
4. ✅ Update Flutter code (Step 4 - Already done!)
5. ⭕ Create login screen (Step 5)
6. Add check for authenticated user before showing home
7. Test Google sign-in flow
8. Add logout button in settings
9. Build task creation UI

---

## 📚 Useful Resources

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Google Sign-In Package](https://pub.dev/packages/google_sign_in)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

---

**Questions?** Check your Supabase logs in Dashboard > Logs for authentication errors.
