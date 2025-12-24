import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';

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

  // Colors from your Calendar Screen theme
  final Color primaryBlue = const Color(0xFF2D5AF0); // Teams Blue
  final Color bgGray = const Color(0xFFF8F9FE);
  final Color darkText = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _selectedDate = widget.task?.dueDate ?? DateTime.now();
    if (widget.task?.dueDate != null) {
      _selectedTime = TimeOfDay.fromDateTime(widget.task!.dueDate!);
    } else {
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
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
                  _buildHeaderSection(),
                  const SizedBox(height: 40),
                  _buildMainInputs(),
                  const SizedBox(height: 40),
                  _buildScheduleSection(),
                ],
              ),
            ),
          ),
          _buildBottomActionButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: darkText, size: 28),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.task != null)
          IconButton(
            icon: const Icon(
                Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () => _confirmDelete(),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.task == null ? "NEW MISSION" : "EDIT TASK",
            style: TextStyle(
              color: primaryBlue,
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
            color: darkText,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildMainInputs() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
          decoration: InputDecoration(
            hintText: "Task Title",
            hintStyle: TextStyle(color: Colors.grey[300]),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
          decoration: InputDecoration(
            hintText: "Add notes or sub-tasks...",
            hintStyle: TextStyle(color: Colors.grey[300]),
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 18,
                color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              "SCHEDULE",
              style: TextStyle(
                color: Colors.grey[500],
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
              label: "Date",
              value: DateFormat('EEE, MMM dd').format(_selectedDate!),
              icon: Icons.today_rounded,
              onTap: () => _pickDate(context),
            ),
            const SizedBox(width: 16),
            _buildPickerTile(
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
            color: bgGray,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: primaryBlue),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: darkText,
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

  Widget _buildBottomActionButton() {
    // CHOICE 1: Vibrant Teams Blue (Recommended)
    final Color buttonColor = primaryBlue;

    // CHOICE 2: Premium Amber/Yellow (Uncomment below to use)
    // final Color buttonColor = const Color(0xFFFFB800);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0), Colors.white],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 65,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _saveTask(),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
            elevation: 12,
            shadowColor: buttonColor.withValues(alpha: 
                0.4), // Soft glow in the button color
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
            widget.task == null ? "Create Task" : "Update Objective",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900, // Extra bold for high-end look
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // --- Logic Methods (Date/Time/Save) ---

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) =>
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(primary: primaryBlue),
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
    // Standard Flutter haptic method
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25)),
            title: const Text(
                "Delete Task?", style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text(
                "Are you sure you want to remove this mission?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")
              ),
              TextButton(
                onPressed: () {
                  context.read<TaskViewModel>().deleteTask(widget.task!.id);
                  Navigator.pop(context); // Close Dialog
                  Navigator.pop(context); // Go back to List
                },
                child: const Text("Delete", style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
  }

  Future<void> _saveTask() async {
    if (_titleController.text
        .trim()
        .isEmpty) {
      return;
    }

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
        id: widget.task?.id ?? DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isCompleted: widget.task?.isCompleted ?? false,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        dueDate: finalDueDate,
      );

      if (widget.task == null) {
        await context.read<TaskViewModel>().addTask(newTask);
      } else {
        await context.read<TaskViewModel>().updateTask(newTask);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error saving task: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

}
