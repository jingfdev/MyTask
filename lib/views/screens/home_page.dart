import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';
import 'package:mytask_project/views/screens/task_form_page.dart'; // 👈 adjust if needed

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0; // 0 = Today, 1 = Upcoming
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final viewModel = context.read<TaskViewModel>();
    await viewModel.fetchTasks();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Task> _getTodayTasks(List<Task> allTasks) {
    final today = DateTime.now();
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.year == today.year &&
          task.dueDate!.month == today.month &&
          task.dueDate!.day == today.day;
    }).toList();
  }

  List<Task> _getUpcomingTasks(List<Task> allTasks) {
    final today = DateTime.now();
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.isAfter(
        DateTime(today.year, today.month, today.day, 23, 59),
      );
    }).toList();
  }

  // ✅ SAME BEHAVIOR AS CALENDAR PAGE
  void _openTaskBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return const TaskFormPage(); // 👈 same widget used in Calendar
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'My Tasks',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ➕ MODERN FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        elevation: 6,
        backgroundColor: Colors.blue[600],
        shape: const CircleBorder(),
        onPressed: _openTaskBottomSheet, // ✅ UPDATED
        child: const Icon(
          Icons.add,
          size: 32,
          color: Colors.white,
        ),
      ),

      body: Column(
        children: [
          // 🔹 TABS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildTab('Today', 0),
                const SizedBox(width: 24),
                _buildTab('Upcoming', 1),
              ],
            ),
          ),

          // 📋 TASK LIST
          Expanded(
            child: Consumer<TaskViewModel>(
              builder: (context, viewModel, _) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allTasks = viewModel.tasks;
                final displayTasks = _selectedTab == 0
                    ? _getTodayTasks(allTasks)
                    : _getUpcomingTasks(allTasks);

                if (displayTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 72,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedTab == 0
                              ? 'No tasks for today'
                              : 'No upcoming tasks',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: displayTasks.length,
                  itemBuilder: (context, index) {
                    final task = displayTasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TaskCard(task: task),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isActive ? Colors.blue[600] : Colors.grey[500],
              fontWeight:
              isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isActive ? 28 : 0,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
