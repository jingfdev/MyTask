import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/animation.dart';

import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:mytask_project/views/widgets/task_card.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    await context.read<TaskViewModel>().fetchTasks();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Task> _applyFilters(List<Task> tasks) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    List<Task> filtered = tasks.where((task) {
      if (_searchQuery.isNotEmpty &&
          !task.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
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
        return task.dueDate!.isAfter(todayEnd);
      }

      return true;
    }).toList();

    // Sort by due date (earliest first), then by completion status
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) { // Fixed: changed from completed to isCompleted
        return a.isCompleted ? 1 : -1;
      }
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _searchQuery.isEmpty
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'My Tasks',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Consumer<TaskViewModel>(
                builder: (context, viewModel, _) {
                  final totalTasks = viewModel.tasks.length;
                  final completedTasks = viewModel.tasks
                      .where((t) => t.isCompleted) // Fixed: changed from completed to isCompleted
                      .length;
                  return Text(
                    '$completedTasks of $totalTasks completed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  );
                },
              ),
            ],
          )
              : Text(
            'Search: "$_searchQuery"',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 24),
            onPressed: () => _showSearchSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Filter Chips
            Container(
              margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterChip('All', 'all', Icons.list_alt),
                  _buildFilterChip('Today', 'today', Icons.today),
                  _buildFilterChip('Upcoming', 'upcoming', Icons.upcoming),
                ],
              ),
            ),

            // Task List
            Expanded(
              child: Consumer<TaskViewModel>(
                builder: (context, viewModel, _) {
                  if (_isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              colorScheme.primary,
                            ),
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading tasks...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final tasks = _applyFilters(viewModel.tasks);

                  if (tasks.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return RefreshIndicator(
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    onRefresh: _loadTasks,
                    child: AnimatedList(
                      key: ValueKey(_selectedFilter + _searchQuery),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      initialItemCount: tasks.length,
                      itemBuilder: (context, index, animation) {
                        final task = tasks[index];
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TaskCard(task: task),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isActive = _selectedFilter == value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _animationController.reset();
        _animationController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isActive ? null : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? Colors.white
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive
                    ? Colors.white
                    : colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = _selectedFilter == 'today'
        ? Icons.today_outlined
        : _selectedFilter == 'upcoming'
        ? Icons.upcoming_outlined
        : Icons.inbox_outlined;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutBack,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                icon,
                size: 64,
                color: colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _getEmptyStateTitle(),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _getEmptyStateSubtitle(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getEmptyStateTitle() {
    if (_searchQuery.isNotEmpty) {
      return 'No tasks found';
    }
    switch (_selectedFilter) {
      case 'today':
        return 'No tasks for today';
      case 'upcoming':
        return 'No upcoming tasks';
      default:
        return 'No tasks yet';
    }
  }

  String _getEmptyStateSubtitle() {
    if (_searchQuery.isNotEmpty) {
      return 'Try searching with different keywords or clear your search to see all tasks.';
    }
    switch (_selectedFilter) {
      case 'today':
        return 'Tasks due today will appear here. Add a task with today\'s date to see it here.';
      case 'upcoming':
        return 'Tasks with future due dates will appear here.';
      default:
        return 'Tap the + button to create your first task and start organizing your work.';
    }
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.2,
          minChildSize: 0.2,
          maxChildSize: 0.3,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        prefixIcon: Icon(Icons.search,
                            color: Theme.of(context).colorScheme.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      textInputAction: TextInputAction.search,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}