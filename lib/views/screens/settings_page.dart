import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader('Account', context),
            _buildSettingTile(
              context,
              icon: Icons.person,
              title: 'Account Details',
              subtitle: 'Manage your account information',
              onTap: () {
                // Navigate to account details
              },
            ),
            _buildSettingTile(
              context,
              icon: Icons.lock,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: () {
                // Navigate to change password
              },
            ),
            Divider(),
            // Preferences Section
            _buildSectionHeader('Preferences', context),
            _buildSwitchTile(
              context,
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Enable dark mode',
              onChanged: (value) {
                context.read<UserViewModel>().updatePreferences(
                      darkMode: value,
                    );
              },
            ),
            _buildSettingTile(
              context,
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification settings',
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey[400]),
              onTap: () {
                // Navigate to notifications
              },
            ),
            _buildSettingTile(
              context,
              icon: Icons.alarm,
              title: 'Reminders',
              subtitle: 'Set reminders for tasks',
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey[400]),
              onTap: () {
                // Navigate to reminders
              },
            ),
            Divider(),
            // Support Section
            _buildSectionHeader('Support', context),
            _buildSettingTile(
              context,
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey[400]),
              onTap: () {
                // Show help dialog
                _showHelpDialog(context);
              },
            ),
            _buildSettingTile(
              context,
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey[400]),
              onTap: () {
                // Navigate to privacy policy
              },
            ),
            SizedBox(height: 20),
            // Sign Out Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: Colors.red[300]!),
                  ),
                  onPressed: () {
                    _showSignOutDialog(context);
                  },
                  child: Text(
                    'Sign Out',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[600]),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ValueChanged<bool> onChanged,
  }) {
    return Consumer<UserViewModel>(
      builder: (context, viewModel, _) {
        return ListTile(
          leading: Icon(icon, color: Colors.blue[600]),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          trailing: Switch(
            value: viewModel.user?.darkMode ?? false,
            onChanged: onChanged,
            activeColor: Colors.blue[600],
          ),
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TaskMaster Support',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            Text(
              'For help or support, please contact us:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 8),
            Text(
              'Email: support@taskmaster.app',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.blue[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Phone: 1-800-TASK-MASTER',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.blue[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out?'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<UserViewModel>().signOut();
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/welcome');
            },
            child: Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
