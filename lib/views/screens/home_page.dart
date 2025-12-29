import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';
import 'package:confetti/confetti.dart';
import 'package:table_calendar/table_calendar.dart'; // Required for isSameDay

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isDashboardExpanded = false; // Controls the dashboard state
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
    final viewModel = context.read<TaskViewModel>();
    await viewModel.fetchTasks();
    if (mounted) setState(() => _isLoading = false);
  }

  // --- STATS LOGIC ---
  int _calculateStreak(List<Task> allTasks) {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    while (true) {
      final tasksForDay = allTasks.where((t) => isSameDay(t.dueDate, checkDate)).toList();
      if (tasksForDay.isNotEmpty && tasksForDay.every((t) => t.isCompleted)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (isSameDay(checkDate, DateTime.now())) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  List<Task> _getTodayTasks(List<Task> allTasks) {
    final now = DateTime.now();
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate, now);
    }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  List<Task> _getUpcomingTasks(List<Task> allTasks) {
    final todayEnd = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      return task.dueDate!.isAfter(todayEnd);
    }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: colorScheme.surface,
            elevation: 0,
            centerTitle: false,
            title: Text('My Tasks', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 28)),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(Icons.add, color: colorScheme.primary, size: 26),
                  onPressed: () => Navigator.of(context).pushNamed('/add-task'),
                ),
              ),
            ],
          ),
          body: Consumer<TaskViewModel>(
            builder: (context, viewModel, _) {
              final todayTasks = _getTodayTasks(viewModel.tasks);
              final displayTasks = _selectedTab == 0 ? todayTasks : _getUpcomingTasks(viewModel.tasks);

              return Column(
                children: [
                  // --- NEW DASHBOARD FEATURE ---
                  _buildExpandableDashboard(viewModel),

                  // --- TAB NAVIGATION ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
                        _buildTab('Today', 0),
                        const SizedBox(width: 24),
                        _buildTab('Upcoming', 1),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : displayTasks.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: displayTasks.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: TaskCard(task: displayTasks[index]),
                                ),
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --- DASHBOARD UI COMPONENTS ---

  Widget _buildExpandableDashboard(TaskViewModel viewModel) {
    final todayTasks = _getTodayTasks(viewModel.tasks);
    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final totalCount = todayTasks.length;
    int streak = _calculateStreak(viewModel.tasks);
    double progress = totalCount == 0 ? 0 : completedCount / totalCount;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 5 && !_isDashboardExpanded) setState(() => _isDashboardExpanded = true);
        if (details.delta.dy < -5 && _isDashboardExpanded) setState(() => _isDashboardExpanded = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        height: _isDashboardExpanded ? 200 : 85,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isDashboardExpanded
                ? _buildFullDashboard(totalCount, completedCount, streak, progress)
                : _buildCompactDashboard(totalCount, completedCount, streak, progress),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDashboard(int total, int done, int streak, double progress) {
    return Row(
      key: const ValueKey("compact"),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TODAY'S PROGRESS", style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text("$done/$total Tasks Done", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        const Spacer(),
        if (streak > 0) _buildStreakBadge(streak),
        const SizedBox(width: 12),
        _buildCircularProgress(progress),
      ],
    );
  }

  Widget _buildFullDashboard(int total, int done, int streak, double progress) {
    return Column(
      key: const ValueKey("full"),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("PERFORMANCE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
            Icon(Icons.keyboard_arrow_up_rounded, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildMetricCard("Success Rate", "${(progress * 100).toInt()}%", const Color(0xFF2D5AF0)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildMetricCard("Current Streak", "$streak Days", Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.blue.withValues(alpha: 0.1),
            color: const Color(0xFF2D5AF0),
          ),
        )
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // --- EXISTING UI HELPERS (Refined) ---

  Widget _buildStreakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange[400]!, Colors.orange[700]!]), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
        Text(" $streak", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
      ]),
    );
  }

  Widget _buildCircularProgress(double progress) {
    return SizedBox(
      height: 40, width: 40,
      child: CircularProgressIndicator(
        value: progress,
        backgroundColor: Colors.grey[100],
        color: progress >= 1.0 ? Colors.green : const Color(0xFF2D5AF0),
        strokeWidth: 5,
        strokeCap: StrokeCap.round,
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 18, fontWeight: isActive ? FontWeight.w900 : FontWeight.w500, color: isActive ? const Color(0xFF2D5AF0) : Colors.grey[400])),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4, width: isActive ? 24 : 0,
            decoration: BoxDecoration(color: const Color(0xFF2D5AF0), borderRadius: BorderRadius.circular(2)),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.grey[100]),
          const SizedBox(height: 16),
          Text(_selectedTab == 0 ? 'All caught up for today!' : 'No upcoming tasks', style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
