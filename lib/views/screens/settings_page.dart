// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';
import 'package:mytask_project/viewmodels/theme_viewmodel.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/task_viewmodel.dart';
import 'reminder_settings_page.dart';
import 'profile_page.dart'; // Add this import

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _slideAnimation.value) * 20),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          );
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              floating: false,
              leading: Center(
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: colorScheme.onSurface,
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                  ),
                ),
              ),
              title: Transform.translate(
                offset: const Offset(0, 4),
                child: Text(
                  'Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Account Section
                  _buildSectionHeader(
                    context: context,
                    title: 'Account',
                    icon: Icons.account_circle,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'View your personal information',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    },
                    index: 0,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.email_outlined,
                    title: 'Email Settings',
                    subtitle: 'Manage email preferences',
                    onTap: () {},
                    index: 1,
                  ),

                  // Google Sign-In Tile
                  Consumer<UserViewModel>(
                    builder: (context, userViewModel, child) {
                      final user = userViewModel.user;
                      final isGoogleLinked = user != null &&
                          user.providerData.any((userInfo) => userInfo.providerId == 'google.com');

                      return StreamBuilder<DocumentSnapshot>(
                        stream: user != null
                            ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .snapshots()
                            : null,
                        builder: (context, snapshot) {
                          final userData = snapshot.data?.data() as Map<String, dynamic>?;
                          final displayEmail = userData?['email'] ?? user?.email;
                          final displayName = userData?['displayName'] ?? user?.displayName;

                          return _buildGoogleSignInTile(
                            context: context,
                            isLinked: isGoogleLinked,
                            user: user,
                            displayEmail: displayEmail,
                            displayName: displayName,
                            index: 2,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Preferences Section
                  _buildSectionHeader(
                    context: context,
                    title: 'Preferences',
                    icon: Icons.settings_outlined,
                  ),

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
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          _showSnackBar(
                            context,
                            value ? 'Dark mode enabled' : 'Dark mode disabled',
                          );
                        },
                        index: 3,
                      );
                    },
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Configure notification preferences',
                    onTap: () {},
                    index: 4,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.alarm,
                    title: 'Reminder',
                    subtitle: 'Set up task reminders',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReminderSettingsPage(),
                        ),
                      );
                    },
                    index: 5,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'Change app language',
                    onTap: () {},
                    index: 6,
                  ),

                  const SizedBox(height: 8),

                  // Support Section
                  _buildSectionHeader(
                    context: context,
                    title: 'Support',
                    icon: Icons.help_outline,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.help_center_outlined,
                    title: 'Help Center',
                    subtitle: 'Find answers and guides',
                    onTap: () {
                      _showHelpBottomSheet(context);
                    },
                    index: 7,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    subtitle: 'Share your thoughts with us',
                    onTap: () {},
                    index: 8,
                  ),

                  _buildAnimatedSettingTile(
                    context: context,
                    icon: Icons.shield_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'Review our privacy practices',
                    onTap: () {},
                    index: 9,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildSignOutButton(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInTile({
    required BuildContext context,
    required bool isLinked,
    required User? user,
    required String? displayEmail,
    required String? displayName,
    required int index,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delay = index * 0.05;
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, 1.0, curve: Curves.easeOut),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (!isLinked) {
                  await _handleGoogleSignIn(context);
                } else {
                  _showConnectedSnackBar(context);
                }
                _animateTap();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Google Icon Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isLinked
                              ? [
                            colorScheme.primary.withOpacity(0.1),
                            colorScheme.primary.withOpacity(0.05),
                          ]
                              : [
                            Colors.white,
                            Colors.grey.shade100,
                          ],
                        ),
                      ),
                      child: isLinked
                          ? Icon(
                        Icons.check_circle,
                        size: 22,
                        color: colorScheme.primary,
                      )
                          : Image.asset(
                        'assets/google.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.g_translate,
                            size: 22,
                            color: colorScheme.onSurface,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName ?? 'Google Account',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isLinked && displayEmail != null)
                            Text(
                              displayEmail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            )
                          else
                            Text(
                              isLinked ? 'Connected' : 'Sign in with Google',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isLinked
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: isLinked ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLinked
                            ? colorScheme.primary.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLinked ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLinked ? 'Connected' : 'Not Linked',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isLinked ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final userViewModel = context.read<UserViewModel>();

    try {
      await userViewModel.signInWithGoogle();

      if (userViewModel.user != null) {
        // MIGRATE GUEST TASKS → FIRESTORE
        await userViewModel.migrateGuestTasksToFirestore();

          await context.read<TaskViewModel>().fetchTasks();

          if (!mounted) return;
          // ignore: use_build_context_synchronously
          _showSnackBar(
            context,
            'Google account linked successfully!',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showSnackBar(
          context,
          'Failed to link Google account. Please try again.',
        );
      }
    }
  }

  void _showConnectedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Google account is already connected'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary.withOpacity(0.8),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required int index,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delay = index * 0.05;
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, 1.0, curve: Curves.easeOut),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                onTap();
                _animateTap();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withOpacity(0.1),
                            colorScheme.primary.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurface.withOpacity(0.3),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSwitchTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required int index,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delay = index * 0.05;
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay, 1.0, curve: Curves.easeOut),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(delay, 1.0, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.1),
                          colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 52,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: value
                          ? LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.8),
                        ],
                      )
                          : null,
                      color: value ? null : colorScheme.surface,
                      border: Border.all(
                        color: value
                            ? Colors.transparent
                            : colorScheme.outline.withOpacity(0.3),
                      ),
                      boxShadow: value
                          ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : null,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        onChanged(!value);
                        _animateTap();
                      },
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutBack,
                            alignment: value
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: value
                                    ? Colors.white
                                    : colorScheme.onSurface.withOpacity(0.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(value ? 0.1 : 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSignOutDialog(context),
          borderRadius: BorderRadius.circular(14),
          highlightColor: Colors.red.withOpacity(0.3),
          splashColor: Colors.red.withOpacity(0.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sign Out',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<UserViewModel>().signSOut();
              if (context.mounted) {
                Navigator.pop(context);
                _showSnackBar(context, 'Signed out successfully');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.help_center,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Help & Support',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildHelpItem(
                          context,
                          title: 'Getting Started',
                          subtitle: 'Learn how to use the app',
                          icon: Icons.play_circle_fill_outlined,
                        ),
                        _buildHelpItem(
                          context,
                          title: 'Managing Tasks',
                          subtitle: 'Create, edit, and organize your tasks',
                          icon: Icons.task_outlined,
                        ),
                        _buildHelpItem(
                          context,
                          title: 'Reminders',
                          subtitle: 'Set up notifications and reminders',
                          icon: Icons.notifications_active_outlined,
                        ),
                        _buildHelpItem(
                          context,
                          title: 'Account Settings',
                          subtitle: 'Manage your profile and preferences',
                          icon: Icons.settings_outlined,
                        ),
                        _buildHelpItem(
                          context,
                          title: 'Contact Support',
                          subtitle: 'Get help from our support team',
                          icon: Icons.support_agent_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHelpItem(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {},
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _animateTap() {
    // Add any tap animation if needed
  }
}