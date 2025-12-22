import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';
import 'package:mytask_project/views/screens/task_form_page.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadTasks();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    await context.read<TaskViewModel>().fetchTasks();
    if (mounted) setState(() => _isLoading = false);
  }

  List<Task> _applyFilters(List<Task> tasks) {
    final now = DateTime.now();
    return tasks.where((task) {
      if (_searchQuery.isNotEmpty && !task.title.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      if (_selectedFilter == 'today') {
        return task.dueDate != null && task.dueDate!.day == now.day && task.dueDate!.month == now.month;
      }
      if (_selectedFilter == 'upcoming') {
        return task.dueDate != null && task.dueDate!.isAfter(DateTime(now.year, now.month, now.day, 23, 59));
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('My Command Center',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24)),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2D5AF0), size: 30),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskFormPage())),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: Consumer<TaskViewModel>(
            builder: (context, viewModel, _) {
              final allTasks = viewModel.tasks;
              final filteredTasks = _applyFilters(allTasks);

              return Column(
                children: [
                  _buildMomentumHeader(allTasks),

                  // Premium Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ),

                  // Filter Row
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('All Tasks', 'all'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Today', 'today'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Upcoming', 'upcoming'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : filteredTasks.isEmpty
                        ? _buildEmptySearch()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TaskCard(task: filteredTasks[index]),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),

        // Confetti layer
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.blue, Colors.green, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }

  Widget _buildMomentumHeader(List<Task> allTasks) {
    final completed = allTasks.where((t) => t.isCompleted).length;
    final total = allTasks.length;
    final double progress = total == 0 ? 0 : completed / total;

    // Trigger celebration if 100% complete and tasks exist
    if (progress == 1.0 && total > 0 && !_confettiController.state.toString().contains("playing")) {
      _confettiController.play();
    }

    String greeting = "Welcome back!";
    String subtext = "You have $total tasks to focus on.";

    if (progress == 1.0 && total > 0) {
      greeting = "Mission Complete!";
      subtext = "You've crushed every goal today! 🏆";
    } else if (progress > 0) {
      greeting = "Great Momentum!";
      subtext = "You are ${(progress * 100).toInt()}% done.";
    }

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D5AF0), Color(0xFF5B7FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5AF0).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtext, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          _buildProgressCircle(progress),
        ],
      ),
    );
  }

  Widget _buildProgressCircle(double progress) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 65, height: 65,
          child: CircularProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.15),
            color: Colors.white,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
          ),
        ),
        Text("${(progress * 100).toInt()}%",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2D5AF0) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isActive ? const Color(0xFF2D5AF0) : Colors.grey[200]!),
          boxShadow: isActive ? [BoxShadow(color: const Color(0xFF2D5AF0).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey[500], fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('All clear for now!', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}