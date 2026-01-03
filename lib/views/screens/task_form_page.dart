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
            TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
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
              color: colorScheme.onSurface.withOpacity(0.6),
              height: 1.5),
          decoration: InputDecoration(
            hintText: "Add notes or sub-tasks...",
            hintStyle:
            TextStyle(color: colorScheme.onSurface.withOpacity(0.3)),
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
                size: 18, color: colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(width: 8),
            Text(
              "SCHEDULE",
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.5),
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
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
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
                  color: colorScheme.onSurface.withOpacity(0.5),
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
            colorScheme.surface.withOpacity(0),
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
            shadowColor: colorScheme.primary.withOpacity(0.4),
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

      final newTask = Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isCompleted: widget.task?.isCompleted ?? false,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        dueDate: finalDueDate,
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
            // Optional: migrate existing guest tasks after login
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}