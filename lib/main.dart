import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'firebase_options.dart';

import 'package:mytask_project/services/notification_service.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';
import 'package:mytask_project/viewmodels/notification_viewmodel.dart';
import 'package:mytask_project/viewmodels/theme_viewmodel.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/views/screens/welcome_screen.dart';
import 'package:mytask_project/views/screens/onboarding_screen.dart';
import 'package:mytask_project/views/screens/task_list_screen.dart';
import 'package:mytask_project/views/screens/task_form_page.dart';
import 'package:mytask_project/views/screens/calendar_screen.dart';
import 'package:mytask_project/views/screens/settings_page.dart';
import 'package:mytask_project/views/screens/main_navigation_wrapper.dart';
import 'package:mytask_project/views/screens/notifications_screen.dart';

/// Global navigator key for handling notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');

  // Show notification even in background
  if (message.notification != null) {
    await NotificationService().showInstantNotification(
      title: message.notification!.title ?? 'New Notification',
      body: message.notification!.body ?? '',
      payload: message.data,
    );
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize timezone database
    tz.initializeTimeZones();

    // Set local timezone - THIS IS CRITICAL FOR SCHEDULED NOTIFICATIONS
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('✅ Timezone set to: $timeZoneName');

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ AUTO GUEST LOGIN (ANONYMOUS)
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    // Initialize theme before running app
    final themeViewModel = ThemeViewModel();
    await themeViewModel.initialize();

    // Set navigator key before notifications
    NotificationService().setNavigatorKey(navigatorKey);

    // Initialize notifications
    await NotificationService().initialize();

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    runApp(MyApp(initialThemeViewModel: themeViewModel));
  } catch (e, stackTrace) {
    debugPrint('❌ Error in main: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  final ThemeViewModel? initialThemeViewModel;

  const MyApp({super.key, this.initialThemeViewModel});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeViewModel>.value(
          value: initialThemeViewModel ?? ThemeViewModel(),
        ),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => TaskViewModel()),
        ChangeNotifierProvider(create: (_) => NotificationViewModel()),
      ],
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final userVm = Provider.of<UserViewModel>(
              context,
              listen: false,
            );

            NotificationService().onTokenGenerated = (token) {
              userVm.saveFcmToken(token);
            };
          });

          return Consumer<ThemeViewModel>(
            builder: (context, themeVm, _) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                title: 'TaskMaster',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.light,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blue,
                    brightness: Brightness.light,
                  ),
                ),
                darkTheme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blue,
                    brightness: Brightness.dark,
                  ),
                ),
                themeMode: themeVm.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                home: WelcomeScreen(),
                routes: {
                  '/welcome': (_) => WelcomeScreen(),
                  '/onboarding': (_) => OnboardingScreen(),
                  '/home': (_) => MainNavigationWrapper(),
                  '/tasks': (_) => TaskListScreen(),
                  '/add-task': (_) => TaskFormPage(),
                  '/calendar': (_) => CalendarScreen(),
                  '/settings': (_) => SettingsPage(),
                  '/notifications': (_) => NotificationsScreen(),
                },
                onGenerateRoute: (settings) {
                  if (settings.name == '/edit-task') {
                    final task = settings.arguments as Task;
                    return MaterialPageRoute(
                      builder: (_) => TaskFormPage(task: task),
                    );
                  }
                  return null;
                },
              );
            },
          );
        },
      ),
    );
  }
}
