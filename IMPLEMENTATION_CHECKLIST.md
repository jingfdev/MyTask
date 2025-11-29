# 📋 Supabase Integration Checklist

Track your progress as you set up Google authentication and the database.

---

## ✅ Backend Setup (Supabase)

- [ ] **Step 1: Google OAuth Setup**
  - [ ] Create Google OAuth credentials at [Google Cloud Console](https://console.cloud.google.com)
  - [ ] Copy Client ID and Client Secret
  - [ ] Add redirect URI: `https://[YOUR-PROJECT-ID].supabase.co/auth/v1/callback`
  - [ ] Enable Google provider in Supabase Dashboard > Authentication > Providers

- [ ] **Step 2: Create Database Schema**
  - [ ] Open `SUPABASE_SETUP.sql` file
  - [ ] Copy all SQL code
  - [ ] Go to Supabase > SQL Editor > New Query
  - [ ] Paste and run SQL
  - [ ] Verify tables appear: users, tasks, categories, subtasks, task_tags, task_attachments

- [ ] **Step 3: Enable Row Level Security**
  - [ ] Verify RLS policies are created (should be automatic from SQL)
  - [ ] Test by going to Database > tables and checking each table has RLS enabled

---

## ✅ Flutter App Setup (Already Done!)

- [x] Added `google_sign_in` package
- [x] Created `lib/config/supabase_config.dart`
- [x] Updated `lib/models/user.dart` with Google auth fields
- [x] Added Google Sign-In methods to `lib/services/supabase_service.dart`:
  - [x] `signInWithGoogle()`
  - [x] `getUserProfile()`
  - [x] `updateUserSettings()`
  - [x] `createCategory()`
  - [x] `getCategories()`
  - [x] `createSubtask()`
  - [x] `getSubtasks()`

### Next Flutter Tasks:

- [ ] Run `flutter pub get` to install packages
- [ ] Create login/authentication screen
- [ ] Add authentication guard to prevent unauthorized access
- [ ] Create welcome/onboarding screen with Google Sign-In button
- [ ] Add user profile display
- [ ] Add logout functionality in settings
- [ ] Implement category management UI
- [ ] Implement task creation with categories
- [ ] Add subtask support to task details screen

---

## ✅ Platform-Specific Configuration

### Android
- [ ] Note your app's `applicationId` from `android/app/build.gradle`
- [ ] Get SHA-1 fingerprint: `cd android && ./gradlew signingReport`
- [ ] Add SHA-1 to Google Cloud Console OAuth credentials

### iOS
- [ ] Note Bundle Identifier from `ios/Runner.xcodeproj`
- [ ] Create iOS OAuth 2.0 Client ID in Google Cloud Console
- [ ] Download and configure Google config file

### Web (if supporting web)
- [ ] Add web OAuth redirect URI: `http://localhost:3000`

---

## 🧪 Testing Checklist

- [ ] Google sign-in works on Android
- [ ] Google sign-in works on iOS
- [ ] User data appears in Supabase `users` table after sign-in
- [ ] Can create tasks after sign-in
- [ ] Tasks are only visible to the user who created them
- [ ] Can create and manage categories
- [ ] Can add subtasks to tasks
- [ ] Sign-out works correctly
- [ ] Re-signing in shows existing user data
- [ ] Notifications work (optional but recommended)

---

## 📱 User Flow (What Users Will Experience)

1. **Open App** → Welcome Screen
2. **Click "Sign in with Google"** → Google popup
3. **Select Google account** → Redirects to app
4. **User data saved** → Automatic user table entry
5. **Navigate to Home** → Can create tasks
6. **Create Task** → Appears in tasks table
7. **Edit/Delete Task** → Database updates
8. **Settings** → Can change preferences
9. **Logout** → Auth signs out

---

## 📚 Key Files to Reference

- `SUPABASE_SETUP.sql` - Database schema (run this in Supabase)
- `SETUP_GUIDE.md` - Detailed setup instructions
- `lib/config/supabase_config.dart` - Credentials
- `lib/services/supabase_service.dart` - All database methods
- `lib/models/user.dart` - User model with auth fields

---

## 🔗 Important Links

- Supabase Dashboard: https://supabase.com/dashboard
- Google Cloud Console: https://console.cloud.google.com
- Flutter Google Sign-In Docs: https://pub.dev/packages/google_sign_in
- Supabase Flutter Guide: https://supabase.com/docs/guides/getting-started/quickstarts/flutter

---

## ❓ Need Help?

- Check Supabase logs: Dashboard > Logs
- Enable Flutter debug output: `flutter run -v`
- Read error messages carefully - they usually tell you exactly what's wrong
- Check Row Level Security policies if data isn't showing
- Verify Google OAuth credentials are correct in Supabase

---

**Status:** Backend code is ready! Now execute the backend setup steps above.
