# Dark Mode - Code Snippets Reference

## ThemeViewModel (Complete Class)

```dart
// File: lib/viewmodels/theme_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode_enabled';
  
  bool _isDarkMode = false;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  /// Initialize theme from shared preferences
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isDarkMode = _prefs?.getBool(_darkModeKey) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing ThemeViewModel: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Toggle dark mode and persist preference
  Future<void> toggleDarkMode({bool? value}) async {
    try {
      final newValue = value ?? !_isDarkMode;
      _isDarkMode = newValue;
      
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_darkModeKey, newValue);
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error toggling dark mode: $e');
    }
  }

  /// Get current theme data based on dark mode setting
  ThemeData getThemeData() {
    if (_isDarkMode) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      );
    }
  }
}
```

---

## main.dart Changes

### Import
```dart
import 'package:mytask_project/viewmodels/theme_viewmodel.dart';
```

### In main()
```dart
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // ... other initialization code ...
    
    // Initialize theme before running app
    final themeViewModel = ThemeViewModel();
    await themeViewModel.initialize();
    
    // ... more initialization ...
    
    runApp(MyApp(themeViewModel: themeViewModel));
  } catch (e, stackTrace) {
    // ... error handling ...
  }
}
```

### MyApp Class
```dart
class MyApp extends StatelessWidget {
  final ThemeViewModel? themeViewModel;

  const MyApp({super.key, this.themeViewModel});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeViewModel()..initialize()),
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
                theme: themeVm.getThemeData(),  // Dynamic theme
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
```

---

## settings_page.dart Changes

### Import
```dart
import 'package:mytask_project/viewmodels/theme_viewmodel.dart';
```

### Remove from _SettingsPageState
```dart
// REMOVE THIS LINE:
bool _darkMode = false;
```

### In build() method, find and replace dark mode tile:

**OLD CODE:**
```dart
_buildAnimatedSwitchTile(
  context: context,
  icon: Icons.dark_mode_outlined,
  title: 'Dark Mode',
  subtitle: 'Switch between light and dark theme',
  value: _darkMode,
  onChanged: (value) {
    setState(() => _darkMode = value);
    _showSnackBar(
      context,
      value ? 'Dark mode enabled' : 'Dark mode disabled',
    );
  },
  index: 3,
),
```

**NEW CODE:**
```dart
Consumer<ThemeViewModel>(
  builder: (context, themeVm, _) {
    return _buildAnimatedSwitchTile(
      context: context,
      icon: Icons.dark_mode_outlined,
      title: 'Dark Mode',
      subtitle: 'Switch between light and dark theme',
      value: themeVm.isDarkMode,
      onChanged: (value) async {
        await themeVm.toggleDarkMode(value: value);
        _showSnackBar(
          context,
          value ? 'Dark mode enabled' : 'Dark mode disabled',
        );
      },
      index: 3,
    );
  },
),
```

### Also remove this unused variable from build():
```dart
// REMOVE THIS LINE:
final isDarkMode = theme.brightness == Brightness.dark;
```

---

## Complete File Checklist

### ✅ lib/viewmodels/theme_viewmodel.dart
- [x] File created
- [x] All imports present
- [x] ThemeViewModel class defined
- [x] _darkModeKey constant defined
- [x] Private variables defined
- [x] Getters defined
- [x] initialize() method complete
- [x] toggleDarkMode() method complete
- [x] getThemeData() method complete

### ✅ lib/main.dart
- [x] ThemeViewModel import added
- [x] themeViewModel created in main()
- [x] themeViewModel.initialize() called
- [x] MyApp constructor updated
- [x] ThemeViewModel added to MultiProvider
- [x] Consumer<ThemeViewModel> wrapping MaterialApp
- [x] theme: themeVm.getThemeData() used

### ✅ lib/views/screens/settings_page.dart
- [x] ThemeViewModel import added
- [x] _darkMode variable removed
- [x] Dark mode toggle wrapped in Consumer
- [x] onChanged uses themeVm.toggleDarkMode()
- [x] value uses themeVm.isDarkMode
- [x] Unused isDarkMode variable removed

---

## Usage Examples

### Reading Dark Mode State
```dart
// In any widget
Consumer<ThemeViewModel>(
  builder: (context, themeVm, _) {
    if (themeVm.isDarkMode) {
      // Dark mode is on
    } else {
      // Light mode is on
    }
    return SizedBox();
  },
)

// Or directly
final isDark = context.read<ThemeViewModel>().isDarkMode;
```

### Toggling Dark Mode
```dart
// In any widget
final themeVm = context.read<ThemeViewModel>();
await themeVm.toggleDarkMode();  // Toggle
await themeVm.toggleDarkMode(value: true);   // Force on
await themeVm.toggleDarkMode(value: false);  // Force off
```

### Getting Theme Data
```dart
// In main.dart (already done)
final themeData = themeVm.getThemeData();
```

---

## Testing Code

```dart
// In any test file or debug console
// Get current state
final isDark = context.read<ThemeViewModel>().isDarkMode;
print('Dark mode is: ${isDark ? "ON" : "OFF"}');

// Toggle
await context.read<ThemeViewModel>().toggleDarkMode();
print('Toggled! Now: ${context.read<ThemeViewModel>().isDarkMode}');

// Set specific state
await context.read<ThemeViewModel>().toggleDarkMode(value: true);
print('Set to dark: ${context.read<ThemeViewModel>().isDarkMode}');
```

---

## Common Patterns

### Check if dark mode in any widget
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
```

### Use different colors for light/dark
```dart
final color = Theme.of(context).brightness == Brightness.dark
    ? Colors.white
    : Colors.black;
```

### Custom theme data access
```dart
final colorScheme = Theme.of(context).colorScheme;
final primary = colorScheme.primary;
```

---

## Debug Logging

The ThemeViewModel includes debug logging:
```dart
debugPrint('❌ Error initializing ThemeViewModel: $e');
debugPrint('❌ Error toggling dark mode: $e');
```

Check console to see any errors.

---

## SharedPreferences

The preference is stored as:
```dart
// Key: 'dark_mode_enabled'
// Value: boolean (true = dark, false = light)
// Stored in: Device local storage
```

To inspect:
```dart
final prefs = await SharedPreferences.getInstance();
final isDark = prefs.getBool('dark_mode_enabled') ?? false;
print('Stored preference: $isDark');
```

To clear:
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.remove('dark_mode_enabled');
```

---

## Summary

This is everything you need to understand and maintain dark mode in your app!


