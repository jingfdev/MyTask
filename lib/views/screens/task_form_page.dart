import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/viewmodels/user_viewmodel.dart';
import 'package:mytask_project/widgets/dialogs/auth_prompt_dialog.dart';

class TaskFormPage extends StatefulWidget {
  final Task? task;
  const TaskFormPage({super.key, this.task});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _reminderTime;
  bool _enableReminder = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');

    // Set initial date
    _selectedDate = widget.task?.dueDate ?? DateTime.now();

    if (widget.task?.dueDate != null) {
      // If editing, use the existing task's time
      _selectedTime = TimeOfDay.fromDateTime(widget.task!.dueDate!);
    } else {
      // LOGIC: Default to the next 5-minute interval for a cleaner UI
      final now = DateTime.now();
      int minutesToAdd = 5 - (now.minute % 5);
      DateTime suggestedTime = now.add(Duration(minutes: minutesToAdd));

      _selectedTime = TimeOfDay(
        hour: suggestedTime.hour,
        minute: suggestedTime.minute,
      );
    }

    // Initialize reminder time from existing task if available
    if (widget.task?.reminderTime != null) {
      _reminderTime = widget.task!.reminderTime;
      _enableReminder = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(theme, colorScheme),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildHeaderSection(colorScheme),
                  const SizedBox(height: 40),
                  _buildMainInputs(colorScheme),
                  const SizedBox(height: 40),
                  _buildScheduleSection(colorScheme),
                ],
              ),
            ),
          ),
          _buildBottomActionButton(colorScheme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: colorScheme.onSurface, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.task != null)
          IconButton(
            icon:
            Icon(Icons.delete_outline_rounded, color: colorScheme.error),
            onPressed: () => _confirmDelete(),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.task == null ? "NEW MISSION" : "EDIT TASK",
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.task == null
              ? "What's on your\nmind?"
              : "Refine your\nobjective",
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildMainInputs(ColorScheme colorScheme) {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: "Task Title",
            hintStyle:
            TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5),
          decoration: InputDecoration(
            hintText: "Add notes or sub-tasks...",
            hintStyle:
            TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3)),
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              "SCHEDULE",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildPickerTile(
              colorScheme: colorScheme,
              label: "Date",
              value: DateFormat('EEE, MMM dd').format(_selectedDate!),
              icon: Icons.today_rounded,
              onTap: () => _pickDate(context),
            ),
            const SizedBox(width: 16),
            _buildPickerTile(
              colorScheme: colorScheme,
              label: "Time",
              value: _selectedTime!.format(context),
              icon: Icons.access_time_filled_rounded,
              onTap: () => _pickTime(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // ✅ REMINDER SECTION
        _buildReminderSection(colorScheme),
      ],
    );
  }

  Widget _buildPickerTile({
    required ColorScheme colorScheme,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionButton(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 40),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface.withValues(alpha: 0),
            colorScheme.surface
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _saveTask(),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            elevation: 12,
            shadowColor: colorScheme.primary.withValues(alpha: 0.4),
          ),
          child: _isLoading
              ? CircularProgressIndicator(color: colorScheme.onPrimary)
              : Text(
            widget.task == null ? "Create Task" : "Update Objective",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_active_rounded,
                size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              "REMINDER",
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Reminder toggle switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.alarm, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    "Set Reminder",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _enableReminder,
                onChanged: (value) {
                  setState(() {
                    _enableReminder = value;
                    if (!value) {
                      _reminderTime = null;
                    } else {
                      // Default: 30 minutes before due date
                      _reminderTime = _selectedDate!.subtract(
                        const Duration(minutes: 30),
                      );
                    }
                  });
                },
              ),
            ],
          ),
        ),
        // Show reminder time picker only if reminder is enabled
        if (_enableReminder) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickReminderDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          "REMINDER DATE",
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEE, MMM dd')
                              .format(_reminderTime ?? DateTime.now()),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickReminderTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time_filled_rounded,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          "REMINDER TIME",
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now())
                              .format(context),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info text about reminder timing
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You'll be notified at this time",
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Logic Methods ---

  Future<void> _pickDate(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: colorScheme.copyWith(
            primary: colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime!,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _pickReminderDate(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? _selectedDate!,
      firstDate: DateTime.now(),
      lastDate: _selectedDate!,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: colorScheme.copyWith(
            primary: colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final reminderTime = _reminderTime ?? DateTime.now();
      setState(() => _reminderTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            reminderTime.hour,
            reminderTime.minute,
          ));
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final reminderTime = _reminderTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(reminderTime),
    );
    if (picked != null) {
      final date = _reminderTime ?? DateTime.now();
      setState(() => _reminderTime = DateTime(
            date.year,
            date.month,
            date.day,
            picked.hour,
            picked.minute,
          ));
    }
  }

  void _confirmDelete() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Delete Task?",
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text("Are you sure you want to remove this mission?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              context.read<TaskViewModel>().deleteTask(widget.task!.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final DateTime finalDueDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Validate reminder time if enabled
      if (_enableReminder && _reminderTime != null) {
        if (_reminderTime!.isAfter(finalDueDate)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reminder time must be before due date'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final newTask = Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isCompleted: widget.task?.isCompleted ?? false,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        dueDate: finalDueDate,
        reminderTime: _enableReminder ? _reminderTime : null,
      );

      final userVm = context.read<UserViewModel>();
      final taskVm = context.read<TaskViewModel>();

      // ✅ FIX: For editing existing tasks, just use the updateTask method
      // which already handles both guest and logged-in cases
      if (widget.task != null) {
        // Editing existing task
        await taskVm.updateTask(newTask);
      } else {
        // Creating new task
        final isGuest = userVm.user == null || userVm.user!.isAnonymous;

        if (isGuest) {
          final shouldSignIn = await showAuthPromptDialog(context);

          if (shouldSignIn) {
            await userVm.signInWithGoogle();
            await userVm.migrateGuestTasksToFirestore();

            // After sign in, use Firestore method
            await taskVm.addTaskToFirestore(newTask);
          } else {
            // User chose to continue as guest
            await taskVm.addTaskLocal(newTask);
          }
        } else {
          // Already signed in
          await taskVm.addTaskToFirestore(newTask);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error saving task: $e');
      // Show error to user if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}


