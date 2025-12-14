import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _selectedFilter = 'all'; // all | today | upcoming
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    await context.read<TaskViewModel>().fetchTasks();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Task> _applyFilters(List<Task> tasks) {
    final now = DateTime.now();

    List<Task> filtered = tasks.where((task) {
      if (_searchQuery.isNotEmpty &&
          !task.title
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())) {
        return false;
      }

      if (_selectedFilter == 'today') {
        if (task.dueDate == null) return false;
        return task.dueDate!.year == now.year &&
            task.dueDate!.month == now.month &&
            task.dueDate!.day == now.day;
      }

      if (_selectedFilter == 'upcoming') {
        if (task.dueDate == null) return false;
        return task.dueDate!.isAfter(
          DateTime(now.year, now.month, now.day, 23, 59),
        );
      }

      return true;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Upcoming', 'upcoming'),
                ],
              ),
            ),
          ),

          // Task List
          Expanded(
            child: Consumer<TaskViewModel>(
              builder: (context, viewModel, _) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = _applyFilters(viewModel.tasks);

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks found',
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
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
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

  Widget _buildFilterChip(String label, String value) {
    final isActive = _selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue[600]! : Colors.grey[200]!,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter task title...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
