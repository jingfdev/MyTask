import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0; // 0: Today, 1: Upcoming

  @override
  void initState() {
    super.initState();
    // Initialize tasks on page load
    Future.microtask(() {
      context.read<TaskViewModel>().initialize();
    });
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
            icon: Icon(Icons.add, color: Colors.blue[600], size: 28),
            onPressed: () {
              Navigator.of(context).pushNamed('/add-task');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildTab('Today', 0),
                SizedBox(width: 16),
                _buildTab('Upcoming', 1),
              ],
            ),
          ),
          // Task List
          Expanded(
            child: Consumer<TaskViewModel>(
              builder: (context, viewModel, _) {
                if (viewModel.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }

                List<Task> displayTasks = _selectedTab == 0
                    ? viewModel.getTodayTasks()
                    : viewModel.getUpcomingTasks();

                if (displayTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 60, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          _selectedTab == 0
                              ? 'No tasks for today'
                              : 'No upcoming tasks',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: displayTasks.length,
                  itemBuilder: (context, index) {
                    final task = displayTasks[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
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
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isActive ? Colors.blue[600] : Colors.grey[500],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          if (isActive)
            Container(
              margin: EdgeInsets.only(top: 8),
              height: 3,
              width: 30,
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
