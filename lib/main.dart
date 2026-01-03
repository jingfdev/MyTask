import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Restore notification logic
  if (message.notification != null) {
    await NotificationService().showInstantNotification(
      title: message.notification!.title ?? 'New Notification',
      body: message.notification!.body ?? '',
      payload: message.data,
    );
  }

  // (optional) restore debugPrint if your team wants it
  // debugPrint('Handling background message: ${message.messageId}');
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize timezone database - THIS IS CRITICAL FOR SCHEDULED NOTIFICATIONS
    debugPrint('🌍 Initializing timezone database...');
    tz.initializeTimeZones();
    debugPrint('✅ Timezone database initialized');

    // Set local timezone
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint('📍 Detected timezone: $timeZoneName');

      final location = tz.getLocation(timeZoneName);
      tz.setLocalLocation(location);
      debugPrint('✅ Timezone set to: $timeZoneName');
      debugPrint('   Current timezone offset: ${location.currentTimeZone}');
    } catch (e) {
      debugPrint('⚠️ Error setting timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.UTC);
    }

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize theme before running app
    final themeViewModel = ThemeViewModel();
    await themeViewModel.initialize();

    // Set navigator key before notifications
    NotificationService().setNavigatorKey(navigatorKey);

    // Initialize notifications (unchanged)
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

/// Runs one-time auth bootstrapping AFTER providers exist:
/// - Ensure guest user (anonymous) exists
/// - Handle web redirect result (Google sign-in redirect)
class AppBootstrap extends StatefulWidget {
  final Widget child;
  const AppBootstrap({super.key, required this.child});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ran = false;

  @override
  void initState() {
    super.initState();

    // Run after first frame so Provider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _ran) return;
      _ran = true;

      final userVm = context.read<UserViewModel>();

      // ✅ Always have a guest user if not logged in
      await userVm.ensureGuestUser();

      // ✅ Important for WEB redirect flow (popup blocked -> redirect)
      await userVm.handleRedirectResult();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
          // Hook FCM token -> save to Firestore whenever it's generated/refreshed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final userVm = Provider.of<UserViewModel>(context, listen: false);
            final taskVm = Provider.of<TaskViewModel>(context, listen: false);

            NotificationService().onTokenGenerated = (token) {
              userVm.saveFcmToken(token);
            };

            // ✅ Reschedule notifications on app startup
            taskVm.rescheduleAllReminders();
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

                // ✅ Wrap your first screen with AppBootstrap
                home: AppBootstrap(child: WelcomeScreen()),

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