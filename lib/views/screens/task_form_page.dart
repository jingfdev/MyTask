import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';

class TaskFormPage extends StatefulWidget {
  final Task? task;

  const TaskFormPage({Key? key, this.task}) : super(key: key);

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _enableReminder = false;
  ReminderTime _selectedReminder = ReminderTime.none;
  TimeOfDay? _customReminderTime;

  bool _isLoading = false;

  // Reminder options
  final List<ReminderOption> _reminderOptions = [
    ReminderOption('None', ReminderTime.none),
    ReminderOption('At time of event', ReminderTime.atTime),
    ReminderOption('5 minutes before', ReminderTime.fiveMinutes),
    ReminderOption('10 minutes before', ReminderTime.tenMinutes),
    ReminderOption('15 minutes before', ReminderTime.fifteenMinutes),
    ReminderOption('30 minutes before', ReminderTime.thirtyMinutes),
    ReminderOption('1 hour before', ReminderTime.oneHour),
    ReminderOption('2 hours before', ReminderTime.twoHours),
    ReminderOption('1 day before', ReminderTime.oneDay),
    ReminderOption('Custom time', ReminderTime.custom),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _selectedDate = widget.task?.dueDate;

    if (widget.task?.dueDate != null) {
      _selectedTime = TimeOfDay.fromDateTime(widget.task!.dueDate!);
      _enableReminder = widget.task?.hasReminder ?? false;

      // Set reminder type if task has it
      if (widget.task?.reminderType != null) {
        _selectedReminder = widget.task!.reminderType!;
      }

      // Set custom reminder time if exists
      if (widget.task?.reminderTime != null) {
        _customReminderTime = TimeOfDay.fromDateTime(widget.task!.reminderTime!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.task == null ? 'Add Task' : 'Edit Task',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              label: 'Title',
              controller: _titleController,
              hint: 'e.g. Finalize project report',
            ),
            const SizedBox(height: 20),

            _buildField(
              label: 'Description',
              controller: _descriptionController,
              hint: 'Add more details (optional)',
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // Due Date Section
            _buildSectionHeader('Due Date'),
            const SizedBox(height: 8),

            // 📅 DATE PICKER
            GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate != null
                          ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                          : 'Select a date',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _selectedDate != null
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                    Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
                  ],
                ),
              ),
            ),

            // ⏰ TIME PICKER
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                if (_selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select date first'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                _pickTime(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Select time',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _selectedTime != null
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                    Icon(Icons.access_time, color: Colors.blue[600], size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Reminder Section
            _buildReminderSection(),

            const SizedBox(height: 40),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _saveTask(context),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Save Task'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reminder Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reminder',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Switch.adaptive(
              value: _enableReminder,
              onChanged: (value) {
                setState(() {
                  _enableReminder = value;
                  if (!value) {
                    _selectedReminder = ReminderTime.none;
                  }
                });
              },
              activeColor: Colors.blue[600],
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_enableReminder) ...[
          // Reminder Status Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.blue[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminder is on',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      if (_selectedReminder != ReminderTime.none &&
                          _selectedDate != null &&
                          _selectedTime != null)
                        Text(
                          _getReminderText(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Reminder Options
          Text(
            'Reminder at',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReminderTime>(
                isExpanded: true,
                value: _selectedReminder,
                onChanged: (ReminderTime? newValue) {
                  setState(() {
                    _selectedReminder = newValue ?? ReminderTime.none;
                    if (_selectedReminder == ReminderTime.custom) {
                      _pickCustomReminderTime(context);
                    }
                  });
                },
                items: _reminderOptions.map((ReminderOption option) {
                  return DropdownMenuItem<ReminderTime>(
                    value: option.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          color: option.value == ReminderTime.none
                              ? Colors.grey[500]
                              : Colors.grey[800],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Custom Time Display (if selected)
          if (_selectedReminder == ReminderTime.custom && _customReminderTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Custom reminder at ${_customReminderTime!.format(context)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _pickCustomReminderTime(context),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[600],
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

  String _getReminderText() {
    if (_selectedReminder == ReminderTime.none) return '';

    if (_selectedDate == null || _selectedTime == null) return '';

    final taskDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    DateTime reminderTime = taskDateTime;

    switch (_selectedReminder) {
      case ReminderTime.atTime:
        return 'Reminder at ${_selectedTime!.format(context)}';
      case ReminderTime.fiveMinutes:
        reminderTime = taskDateTime.subtract(const Duration(minutes: 5));
        break;
      case ReminderTime.tenMinutes:
        reminderTime = taskDateTime.subtract(const Duration(minutes: 10));
        break;
      case ReminderTime.fifteenMinutes:
        reminderTime = taskDateTime.subtract(const Duration(minutes: 15));
        break;
      case ReminderTime.thirtyMinutes:
        reminderTime = taskDateTime.subtract(const Duration(minutes: 30));
        break;
      case ReminderTime.oneHour:
        reminderTime = taskDateTime.subtract(const Duration(hours: 1));
        break;
      case ReminderTime.twoHours:
        reminderTime = taskDateTime.subtract(const Duration(hours: 2));
        break;
      case ReminderTime.oneDay:
        reminderTime = taskDateTime.subtract(const Duration(days: 1));
        break;
      case ReminderTime.custom:
        if (_customReminderTime != null) {
          reminderTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _customReminderTime!.hour,
            _customReminderTime!.minute,
          );
        }
        break;
      case ReminderTime.none:
        return '';
    }

    final dateFormat = DateFormat('MMM dd');
    final timeFormat = DateFormat('hh:mm a');

    if (_selectedReminder == ReminderTime.oneDay) {
      return '${dateFormat.format(reminderTime)} at ${timeFormat.format(reminderTime)}';
    } else {
      return '${_getDurationText(taskDateTime.difference(reminderTime))} before at ${timeFormat.format(reminderTime)}';
    }
  }

  String _getDurationText(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'}';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030, 12, 31),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickCustomReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _customReminderTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _customReminderTime = picked);
    }
  }

  Future<void> _saveTask(BuildContext context) async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final viewModel = context.read<TaskViewModel>();

    final taskDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Calculate reminder time
    DateTime? reminderTime;
    if (_enableReminder && _selectedReminder != ReminderTime.none) {
      reminderTime = _calculateReminderTime(taskDateTime);
    }

    try {
      // FIX: Pass reminderType only if reminder is enabled and not "none"
      final task = Task(
        id: widget.task?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isCompleted: widget.task?.isCompleted ?? false,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        dueDate: taskDateTime,
        reminderTime: reminderTime,
        reminderType: _enableReminder && _selectedReminder != ReminderTime.none
            ? _selectedReminder
            : null,
        hasReminder: _enableReminder,
      );

      if (widget.task == null) {
        await viewModel.addTask(task);
      } else {
        await viewModel.updateTask(task);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  DateTime? _calculateReminderTime(DateTime taskDateTime) {
    switch (_selectedReminder) {
      case ReminderTime.atTime:
        return taskDateTime;
      case ReminderTime.fiveMinutes:
        return taskDateTime.subtract(const Duration(minutes: 5));
      case ReminderTime.tenMinutes:
        return taskDateTime.subtract(const Duration(minutes: 10));
      case ReminderTime.fifteenMinutes:
        return taskDateTime.subtract(const Duration(minutes: 15));
      case ReminderTime.thirtyMinutes:
        return taskDateTime.subtract(const Duration(minutes: 30));
      case ReminderTime.oneHour:
        return taskDateTime.subtract(const Duration(hours: 1));
      case ReminderTime.twoHours:
        return taskDateTime.subtract(const Duration(hours: 2));
      case ReminderTime.oneDay:
        return taskDateTime.subtract(const Duration(days: 1));
      case ReminderTime.custom:
        if (_customReminderTime != null) {
          return DateTime(
            taskDateTime.year,
            taskDateTime.month,
            taskDateTime.day,
            _customReminderTime!.hour,
            _customReminderTime!.minute,
          );
        }
        return null;
      case ReminderTime.none:
        return null;
    }
  }
}



// Keep ReminderOption but it now uses the imported ReminderTime from task.dart
class ReminderOption {
  final String label;
  final ReminderTime value;

  ReminderOption(this.label, this.value);
}