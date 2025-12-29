import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/viewmodels/theme_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';
import 'package:mytask_project/views/screens/task_form_page.dart';
import 'package:table_calendar/table_calendar.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

enum TaskSort { name, date }

class _TaskListScreenState extends State<TaskListScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  TaskSort _currentSort = TaskSort.date; // Default sorting
  bool _isLoading = true;
  bool _isDashboardOpen = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    await context.read<TaskViewModel>().fetchTasks();
    if (mounted) setState(() => _isLoading = false);
  }

  // --- DYNAMIC LOGIC HELPERS ---

  int _calculateStreak(List<Task> allTasks) {
    if (allTasks.isEmpty) return 0;
    int streak = 0;
    DateTime checkDate = DateTime.now();
    while (true) {
      final tasksForDay = allTasks.where((t) => t.dueDate != null && isSameDay(t.dueDate, checkDate)).toList();
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

  double _calculateDailyAverage(List<Task> allTasks) {
    if (allTasks.isEmpty) return 0.0;
    final completedTasks = allTasks.where((t) => t.isCompleted).length;
    final uniqueDays = allTasks
        .where((t) => t.dueDate != null)
        .map((t) => DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day))
        .toSet()
        .length;
    return uniqueDays == 0 ? 0.0 : completedTasks / uniqueDays;
  }

  Color _getDynamicColor(double progress) {
    if (progress <= 0.3) return Colors.redAccent;
    if (progress <= 0.7) return Colors.orangeAccent;
    return Colors.greenAccent[700]!;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildEliteAppBar(),
      body: Consumer<TaskViewModel>(
        builder: (context, viewModel, _) {
          final processedTasks = _getProcessedTasks(viewModel.tasks);
          return Column(
            children: [
              _buildUserDashboard(viewModel.tasks),
              _buildControlPanel(),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                    : _buildTaskList(processedTasks),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DASHBOARD FEATURE (FIXED CIRCLE) ---
  Widget _buildUserDashboard(List<Task> allTasks) {
    final colorScheme = Theme.of(context).colorScheme;
    final done = allTasks.where((t) => t.isCompleted).length;
    final total = allTasks.length;
    final remaining = total - done;
    final progress = total == 0 ? 0.0 : done / total;
    final streak = _calculateStreak(allTasks);
    final dailyAvg = _calculateDailyAverage(allTasks);
    final overdue = allTasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(DateTime.now()) && !t.isCompleted).length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isDashboardOpen = !_isDashboardOpen);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutExpo,
        height: _isDashboardOpen ? 340 : 125,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRect(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      child: _buildUserOrb(progress),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("MY TASK STATUS", style: TextStyle(color: colorScheme.primary, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          const SizedBox(height: 2),
                          Text(progress >= 1.0 ? "EVERYTHING DONE!" : "$done OF $total COMPLETED",
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    if (overdue > 0) _buildAlertBadge(overdue),
                  ],
                ),

                if (_isDashboardOpen) ...[
                  const SizedBox(height: 35),
                  Row(
                    children: [
                      _buildMetricSquare("SUCCESS", "${(progress * 100).toInt()}%", _getDynamicColor(progress), Icons.workspace_premium_rounded),
                      const SizedBox(width: 10),
                      _buildMetricSquare("LEFT", "$remaining", colorScheme.primary.withValues(alpha: 0.5), Icons.pending_actions_rounded),
                      const SizedBox(width: 10),
                      _buildMetricSquare("OVERDUE", "$overdue", overdue > 0 ? Colors.orange : colorScheme.outline.withValues(alpha: 0.2), Icons.notification_important_rounded),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFooterInfo("STREAK", "$streak DAYS", Icons.local_fire_department_rounded, Colors.orange),
                      _buildFooterInfo("DAILY AVG", dailyAvg.toStringAsFixed(1), Icons.bolt_rounded, Colors.purple),
                      _buildKeepGoingTag(progress),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserOrb(double progress) {
    final colorScheme = Theme.of(context).colorScheme;
    Color dynamicColor = _getDynamicColor(progress);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 44, height: 44,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.5,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            color: dynamicColor,
            strokeCap: StrokeCap.round,
          ),
        ),
        Icon(
          progress >= 1.0 ? Icons.emoji_events_rounded : Icons.person_rounded,
          color: dynamicColor.withValues(alpha: 0.4), size: 18,
        ),
      ],
    );
  }

  // --- CONTROL PANEL WITH DOUBLE DROPBOX ---
  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Search Box
          Consumer<ThemeViewModel>(
            builder: (context, themeVm, _) {
              final colorScheme = Theme.of(context).colorScheme;
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search my tasks...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: colorScheme.primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Filter Dropbox (Today, All, etc)
              Expanded(
                child: Consumer<ThemeViewModel>(
                  builder: (context, themeVm, _) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return _buildDropboxContainer(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        icon: Icon(Icons.filter_alt_rounded, color: colorScheme.primary, size: 18),
                        underline: const SizedBox(),
                        onChanged: (String? val) => setState(() => _selectedFilter = val!),
                        items: ['all', 'today', 'upcoming'].map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                        )).toList(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Sort Dropbox (Name, Date)
              Expanded(
                child: Consumer<ThemeViewModel>(
                  builder: (context, themeVm, _) {
                    final colorScheme = Theme.of(context).colorScheme;
                    return _buildDropboxContainer(
                      child: DropdownButton<TaskSort>(
                        value: _currentSort,
                        isExpanded: true,
                        icon: Icon(Icons.sort_rounded, color: colorScheme.primary, size: 18),
                        underline: const SizedBox(),
                        onChanged: (TaskSort? val) => setState(() => _currentSort = val!),
                        items: const [
                          DropdownMenuItem(value: TaskSort.date, child: Text("BY DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          DropdownMenuItem(value: TaskSort.name, child: Text("BY NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropboxContainer({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildMetricSquare(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 7, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterInfo(String label, String val, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5), fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text(val, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildKeepGoingTag(double progress) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        progress >= 1.0 ? "GOAL MET!" : "KEEP GOING!",
        style: TextStyle(color: colorScheme.primary, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildAlertBadge(int overdue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text("LATE: $overdue", style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  AppBar _buildEliteAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PERSONAL", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Text("Tasks", style: TextStyle(color: colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 28),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskFormPage())),
        ),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    if (tasks.isEmpty) return const Center(child: Text("NO TASKS FOUND", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2)));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: tasks.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TaskCard(task: tasks[index]),
      ),
    );
  }

  List<Task> _getProcessedTasks(List<Task> tasks) {
    var filtered = tasks.where((task) {
      bool matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesFilter = true;
      if (_selectedFilter == 'today') {
        matchesFilter = task.dueDate != null && isSameDay(task.dueDate, DateTime.now());
      } else if (_selectedFilter == 'upcoming') {
        matchesFilter = task.dueDate != null && task.dueDate!.isAfter(DateTime.now());
      }
      return matchesSearch && matchesFilter;
    }).toList();

    // Logic for Sorting
    if (_currentSort == TaskSort.name) {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else {
      filtered.sort((a, b) => (a.dueDate ?? DateTime(0)).compareTo(b.dueDate ?? DateTime(0)));
    }
    return filtered;
  }
}
