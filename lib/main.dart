import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:mytask_project/services/notification_service.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/views/screens/welcome_screen.dart';
import 'package:mytask_project/views/screens/onboarding_screen.dart';
import 'package:mytask_project/views/screens/task_list_screen.dart';
import 'package:mytask_project/views/screens/task_form_page.dart';
import 'package:mytask_project/views/screens/calendar_screen.dart';
import 'package:mytask_project/views/screens/settings_page.dart';
import 'package:mytask_project/views/screens/main_navigation_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Initialize notifications
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => TaskViewModel()),
      ],
      child: MaterialApp(
        title: 'TaskMaster',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: WelcomeScreen(),
        routes: {
          '/welcome': (_) => WelcomeScreen(),
          '/onboarding': (_) => OnboardingScreen(),
          '/home': (_) => MainNavigationWrapper(),
          '/tasks': (_) => TaskListScreen(),
          '/add-task': (_) => TaskFormPage(),
          '/calendar': (_) => CalendarScreen(),
          '/settings': (_) => SettingsPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/edit-task') {
            final task = settings.arguments as Task;
            return MaterialPageRoute(
              builder: (context) => TaskFormPage(task: task),
            );
          }
          return null;
        },
      ),
    );
  }
}
