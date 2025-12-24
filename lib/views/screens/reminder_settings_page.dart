import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> with SingleTickerProviderStateMixin {
  bool _enableReminders = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  TimeOfDay _defaultReminderTime = const TimeOfDay(hour: 9, minute: 0);
  int _advanceNoticeMinutes = 30;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final List<int> _advanceNoticeOptions = [15, 30, 60, 120, 1440]; // minutes

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeAnimations();
  }

  void _initializeAnimations() {
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableReminders = prefs.getBool('reminder_enabled') ?? true;
      _soundEnabled = prefs.getBool('reminder_sound') ?? true;
      _vibrationEnabled = prefs.getBool('reminder_vibration') ?? true;
      _advanceNoticeMinutes = prefs.getInt('advance_notice_minutes') ?? 30;

      final hour = prefs.getInt('default_reminder_hour') ?? 9;
      final minute = prefs.getInt('default_reminder_minute') ?? 0;
      _defaultReminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  // UPDATED: Now triggers the service refresh
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', _enableReminders);
    await prefs.setBool('reminder_sound', _soundEnabled);
    await prefs.setBool('reminder_vibration', _vibrationEnabled);
    await prefs.setInt('advance_notice_minutes', _advanceNoticeMinutes);
    await prefs.setInt('default_reminder_hour', _defaultReminderTime.hour);
    await prefs.setInt('default_reminder_minute', _defaultReminderTime.minute);

    // Sync the local notification channel behavior immediately
    await NotificationService().updateNotificationSettings();
  }

  String _getAdvanceNoticeLabel(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes before';
    } else if (minutes == 60) {
      return '1 hour before';
    } else if (minutes < 1440) {
      return '${minutes ~/ 60} hours before';
    } else {
      return '1 day before';
    }
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
              leading: Container(
                margin: const EdgeInsets.only(left: 8, top: 8),
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
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Transform.translate(
                offset: const Offset(0, 4),
                child: Text(
                  'Reminder Settings',
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildSectionHeader(
                      context: context,
                      title: 'General',
                      icon: Icons.tune,
                    ),
                    _buildAnimatedSwitchTile(
                      context: context,
                      icon: Icons.notifications_active,
                      title: 'Enable Reminders',
                      subtitle: 'Receive task reminders',
                      value: _enableReminders,
                      onChanged: (value) async {
                        setState(() => _enableReminders = value);
                        await _saveSettings();
                        _showSnackBar(
                          context,
                          value ? 'Reminders enabled' : 'Reminders disabled',
                        );
                      },
                      index: 0,
                    ),
                    _buildAnimatedSettingTile(
                      context: context,
                      icon: Icons.access_time,
                      title: 'Default Reminder Time',
                      subtitle: _defaultReminderTime.format(context),
                      onTap: _enableReminders ? () => _selectTime(context) : null,
                      index: 1,
                      enabled: _enableReminders,
                    ),
                    _buildAnimatedSettingTile(
                      context: context,
                      icon: Icons.schedule,
                      title: 'Advance Notice',
                      subtitle: _getAdvanceNoticeLabel(_advanceNoticeMinutes),
                      onTap: _enableReminders ? () => _selectAdvanceNotice(context) : null,
                      index: 2,
                      enabled: _enableReminders,
                    ),
                    const SizedBox(height: 8),
                    _buildSectionHeader(
                      context: context,
                      title: 'Alert Settings',
                      icon: Icons.volume_up,
                    ),
                    _buildAnimatedSwitchTile(
                      context: context,
                      icon: Icons.volume_up,
                      title: 'Sound',
                      subtitle: 'Play sound for reminders',
                      value: _soundEnabled,
                      onChanged: _enableReminders
                          ? (value) async {
                        setState(() => _soundEnabled = value);
                        await _saveSettings();
                      }
                          : null,
                      index: 3,
                      enabled: _enableReminders,
                    ),
                    _buildAnimatedSwitchTile(
                      context: context,
                      icon: Icons.vibration,
                      title: 'Vibration',
                      subtitle: 'Vibrate for reminders',
                      value: _vibrationEnabled,
                      onChanged: _enableReminders
                          ? (value) async {
                        setState(() => _vibrationEnabled = value);
                        await _saveSettings();
                      }
                          : null,
                      index: 4,
                      enabled: _enableReminders,
                    ),
                    const SizedBox(height: 24),
                    _buildInfoCard(context),
                    const SizedBox(height: 24),
                    _buildTestButton(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER METHODS (Design Kept Identical) ---

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
          Icon(icon, size: 20, color: colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.9),
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
    required VoidCallback? onTap,
    required int index,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delay = index * 0.05;
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _animationController, curve: Interval(delay, 1.0, curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _animationController, curve: Interval(delay, 1.0, curve: Curves.easeOut)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(16),
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [colorScheme.primary.withValues(alpha: 0.1), colorScheme.primary.withValues(alpha: 0.05)]),
                        ),
                        child: Icon(icon, size: 22, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colorScheme.onSurface.withValues(alpha: 0.3), size: 24),
                    ],
                  ),
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
    required ValueChanged<bool>? onChanged,
    required int index,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final delay = index * 0.05;
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.5, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _animationController, curve: Interval(delay, 1.0, curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _animationController, curve: Interval(delay, 1.0, curve: Curves.easeOut)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [colorScheme.primary.withValues(alpha: 0.1), colorScheme.primary.withValues(alpha: 0.05)]),
                      ),
                      child: Icon(icon, size: 22, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    // Custom Toggle Design
                    GestureDetector(
                      onTap: enabled && onChanged != null ? () => onChanged(!value) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 52,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: value ? LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)]) : null,
                          color: value ? null : colorScheme.surface,
                          border: Border.all(color: value ? Colors.transparent : colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: value ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.3)),
                          ),
                        ),
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

  // NEW: Missing Tile Helper for the Modal Bottom Sheet
  Widget _buildNoticeOptionTile(BuildContext context, int minutes) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _advanceNoticeMinutes == minutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            setState(() => _advanceNoticeMinutes = minutes);
            await _saveSettings();
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 16),
                Text(
                  _getAdvanceNoticeLabel(minutes),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorScheme.primary.withValues(alpha: 0.1), colorScheme.primary.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Reminders will be sent based on your task due dates and selected advance notice time.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.8), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _enableReminders ? _testNotification : null,
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: _enableReminders ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('Test Notification', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(context: context, initialTime: _defaultReminderTime);
    if (picked != null) {
      setState(() => _defaultReminderTime = picked);
      await _saveSettings();
    }
  }

  Future<void> _selectAdvanceNotice(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 16, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Advance Notice', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('Get notified before task deadline', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 24),
                      ..._advanceNoticeOptions.map((minutes) => _buildNoticeOptionTile(context, minutes)).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _testNotification() async {
    // We update settings one last time to be sure service has latest toggles
    await _saveSettings();

    await NotificationService().showInstantNotification(
      title: 'Test Reminder',
      body: 'This is how your task reminders will appear',
      payload: {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    _showSnackBar(context, 'Test notification sent!');
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
