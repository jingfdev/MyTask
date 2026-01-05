# MyTask📝 - To-Do-List App for MAD Class

---

## Project Overview

A simple yet functional to-do list app for creating, organizing, and tracking tasks. Supports categories, priority levels, due dates, notifications, search/filtering, and user accounts with cloud sync.

**Tech Stack:**
- **Framework**: Flutter (Dart)
- **Architecture**: MVVM with Provider state management
- **Backend**: Firebase (Authentication, Firestore, Cloud Messaging)
- **Notifications**: Flutter Local Notifications + Firebase Cloud Messaging (FCM)
- **Platforms**: Mobile, Desktop, Web

---

## How to Set Up

### Prerequisites
- [Flutter SDK (version 3.9.2 or higher)](https://flutter.dev/docs/get-started/install)
- [Dart SDK](https://dart.dev/get-dart)
- [A Firebase project](https://firebase.com)

### Setup Steps

**1. Clone the repo:**
```bash
git clone https://github.com/jingfdev/MyTask.git
cd MyTask
```

**2. Install dependencies:**
```bash
flutter pub get
```

**3. Configure Firebase:**

**4. Run the app:**
```bash
flutter run
```

---

## Set up Firebase

- [Go to Firebase Console and create a new project.](https://console.firebase.google.com).
- Enable Authentication (Google Sign-In) and Firestore Database.
- Add your app platforms (Android, iOS, Web, etc.).
- Download: 
  - google-services.json → place in android/app/
  - GoogleService-Info.plist → place in ios/Runner/
- For web/desktop, configure as per Firebase docs.

**Run the app:**
```bash
flutter run
```

---

## App Features

- **Task Management**: Create, edit, and delete tasks with title, description, due date, priority, and category.
- **Calendar Dashboard**: Visualize your tasks on an interactive calendar view.
- **Reminders & Notifications**: Local notifications with customizable reminder timing (timezone set to Asia/Phnom_Penh).
- **Search & Filter**: Quickly find tasks by keyword, category, priority, or due date.
- **Authentication**: Secure Google Sign-In powered by Firebase Authentication.
- **Guest Mode**: Use core features without signing in (with gentle prompts to create an account for full cloud sync).
- **Cloud Synchronization**: Tasks automatically synced across all your devices via Firebase Firestore.
- **Profile & Settings**: Manage your account, preferences, and app settings.
- **Cross-Platform Support**: Runs natively on Android, iOS, Windows, macOS, Linux, and Web.
  
---

## 📝 License
All Rights Reserved © 2025 <br>
This is an educational project — solid for learning Flutter, MVVM, state management, cross-platform development, and integrating backend services like Firebase.
