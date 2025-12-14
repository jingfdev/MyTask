import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  List<Task> _selectedDateTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDate = DateTime.now();
    _loadTasksForDate(_selectedDate);
  }

  Future<void> _loadTasksForDate(DateTime date) async {
    final viewModel = context.read<TaskViewModel>();
    final tasks = await viewModel.getTasksByDate(date);

    if (mounted) {
      setState(() {
        _selectedDateTasks = tasks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Calendar',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Calendar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDate,
              selectedDayPredicate: (day) =>
                  isSameDay(_selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDate = focusedDay;
                  _isLoading = true;
                });
                _loadTasksForDate(selectedDay);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue[300],
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle:
                Theme.of(context).textTheme.titleMedium!,
              ),
            ),
          ),

          const Divider(),

          // Task list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedDateTasks.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox,
                      size: 60,
                      color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks for this date',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _selectedDateTasks.length,
              itemBuilder: (context, index) {
                final task = _selectedDateTasks[index];
                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 12),
                  child: TaskCard(task: task),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
