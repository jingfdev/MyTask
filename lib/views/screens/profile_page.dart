import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

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

    _loadUserData();
    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    final userViewModel = context.read<UserViewModel>();
    final user = userViewModel.user;

    if (user != null) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _userData = docSnapshot.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          // If user document doesn't exist in Firestore, use Firebase Auth data
          setState(() {
            _userData = {
              'displayName': user.displayName,
              'email': user.email,
              'photoURL': user.photoURL,
              'uid': user.uid,
            };
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _getProviderName() {
    final userViewModel = context.read<UserViewModel>();
    final user = userViewModel.user;

    if (user != null) {
      if (user.providerData.any((userInfo) => userInfo.providerId == 'google.com')) {
        return 'Google';
      } else if (user.providerData.any((userInfo) => userInfo.providerId == 'password')) {
        return 'Email & Password';
      }
    }
    return null;
  }

  String? _getAccountCreatedDate() {
    final userViewModel = context.read<UserViewModel>();
    final user = userViewModel.user;

    if (user != null && user.metadata.creationTime != null) {
      return DateFormat('MMMM dd, yyyy').format(user.metadata.creationTime!);
    }
    return null;
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
    final userViewModel = context.read<UserViewModel>();
    final user = userViewModel.user;

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
                    color: colorScheme.surface.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: colorScheme.onSurface,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
              title: Transform.translate(
                offset: const Offset(0, 4),
                child: Text(
                  'Profile',
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
              child: _isLoading
                  ? _buildLoadingState()
                  : _buildProfileContent(context, user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, User? user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayName = _userData?['displayName'] ?? user?.displayName ?? 'User';
    final email = _userData?['email'] ?? user?.email ?? 'No email';
    final photoURL = _userData?['photoURL'] ?? user?.photoURL;
    final providerName = _getProviderName() ?? 'Unknown';
    final accountCreatedDate = _getAccountCreatedDate() ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Photo Card
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.8),
                        colorScheme.secondary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: photoURL != null && photoURL.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      photoURL,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar(displayName, colorScheme);
                      },
                    ),
                  )
                      : _buildDefaultAvatar(displayName, colorScheme),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Account Information Card
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Email Section
                _buildInfoTile(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: email,
                  isEditable: false,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  indent: 72,
                ),

                // Account Provider Section
                _buildInfoTile(
                  context,
                  icon: Icons.security_outlined,
                  title: 'Account Provider',
                  value: providerName,
                  isEditable: false,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  indent: 72,
                ),

                // Account Created Date Section
                _buildInfoTile(
                  context,
                  icon: Icons.calendar_today_outlined,
                  title: 'Account Created',
                  value: accountCreatedDate,
                  isEditable: false,
                ),
              ],
            ),
          ),

          // User ID Section
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'User ID',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SelectableText(
                      user?.uid ?? 'Unknown',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is your unique identifier in the system',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Last Login Info
          if (_userData?['lastLogin'] != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: _buildInfoTile(
                context,
                icon: Icons.login_outlined,
                title: 'Last Login',
                value: _formatDateTime(_userData!['lastLogin']),
                isEditable: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String displayName, ColorScheme colorScheme) {
    final initials = displayName.isNotEmpty
        ? displayName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
        : 'U';

    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required bool isEditable,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.1),
                  colorScheme.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(
              icon,
              size: 20,
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable)
            IconButton(
              onPressed: () {
                // Handle edit action
              },
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    try {
      if (dateTime is Timestamp) {
        final date = dateTime.toDate();
        return DateFormat('MMMM dd, yyyy • hh:mm a').format(date);
      } else if (dateTime is String) {
        // Parse the string format from your data
        final parsedDate = DateFormat('MMMM dd, yyyy \'at\' hh:mm:ss a z').parse(dateTime);
        return DateFormat('MMMM dd, yyyy • hh:mm a').format(parsedDate);
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
}
