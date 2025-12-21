import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:confetti/confetti.dart';

import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _hideCompleted = false;
  bool _isDashboardExpanded = false;

  late ConfettiController _confettiController;

  final List<Map<String, dynamic>> _celebrations = [
    {"title": "Daily Champion!", "msg": "You've crushed every single task today.", "icon": "🏆", "color": Colors.orangeAccent},
    {"title": "Unstoppable!", "msg": "Perfect day completed!", "icon": "🚀", "color": Colors.blueAccent},
    {"title": "Victory!", "msg": "All items checked.", "icon": "⭐", "color": Colors.purpleAccent},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDate = DateTime.now();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

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

  void _triggerCelebration(int updatedStreak) {
    final random = (List.from(_celebrations)..shuffle()).first;
    _confettiController.play();
    HapticFeedback.vibrate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use the updatedStreak passed from the toggle function
            if (updatedStreak > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: const ShapeDecoration(
                  gradient: LinearGradient(colors: [Colors.orange, Colors.redAccent]), 
                  shape: StadiumBorder()
                ),
                child: Text("$updatedStreak DAY STREAK!", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            Text(random['icon'], style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text(random['title'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: random['color'])),
            const SizedBox(height: 12),
            Text(random['msg'], textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: random['color'], 
                  shape: const StadiumBorder(), 
                  padding: const EdgeInsets.symmetric(vertical: 15)
                ),
                child: const Text("Keep the Flame Alive!", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

void _showQuickAddTask(BuildContext context) {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final viewModel = context.read<TaskViewModel>();

  HapticFeedback.heavyImpact();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text("New Task", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(DateFormat('MMM dd').format(_selectedDate), 
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: "What needs to be done?",
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
              ),
            ),
            TextField(
              controller: descController,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              decoration: InputDecoration(
                hintText: "Add notes (optional)",
                hintStyle: TextStyle(color: Colors.grey[300]),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      // FIX APPLIED HERE: Added required parameters
                      viewModel.addTask(Task(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text,
                        description: descController.text,
                        isCompleted: false,        // Required by your model
                        createdAt: DateTime.now(), // Required by your model
                        dueDate: _selectedDate,
                      ));
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Create Task", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          floatingActionButton: FloatingActionButton(
  onPressed: () => _showQuickAddTask(context),
  backgroundColor: Colors.blueAccent,
  elevation: 4,
  child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
),
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: const Text('My Schedule', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 22)),
            actions: [
              IconButton(
                icon: Icon(_hideCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _hideCompleted ? Colors.blue : Colors.grey),
                onPressed: () => setState(() => _hideCompleted = !_hideCompleted),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() { _selectedDate = DateTime.now(); _focusedDate = DateTime.now(); });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildQuickStatsRow(),
              _buildTeamsCalendarHeader(),
              _buildToggleHandle(),
              // Use NotificationListener to detect scrolling and collapse dashboard
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scroll) {
                    if (scroll.metrics.pixels > 20 && _isDashboardExpanded) {
                      setState(() => _isDashboardExpanded = false);
                    }
                    return false;
                  },
                  child: _buildInfiniteAgenda(),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [Colors.blue, Colors.green, Colors.pink, Colors.orange],
          ),
        ),
      ],
    );
  }

  // --- DASHBOARD WITH GESTURE EXPAND ---
  Widget _buildQuickStatsRow() {
    final viewModel = context.watch<TaskViewModel>();
    final dayTasks = viewModel.tasks.where((t) => isSameDay(t.dueDate, _selectedDate)).toList();
    final completedCount = dayTasks.where((t) => t.isCompleted).length;
    int streak = _calculateStreak(viewModel.tasks);
    double progress = dayTasks.isEmpty ? 0 : completedCount / dayTasks.length;

    return GestureDetector(
      // Drag down to expand dashboard
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 5) setState(() => _isDashboardExpanded = true);
        if (details.delta.dy < -5) setState(() => _isDashboardExpanded = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        height: _isDashboardExpanded ? 220 : 90, 
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: const BoxDecoration(color: Colors.white),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isDashboardExpanded 
                ? _buildFullDashboard(dayTasks.length, completedCount, streak, progress)
                : _buildEnhancedCompactRow(dayTasks.length, completedCount, streak, progress),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCompactRow(int total, int done, int streak, double progress) {
    return Container(
      key: const ValueKey("compact"),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.04), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          _buildStatItem("TASKS", "$done/$total", Colors.blueAccent),
          const SizedBox(width: 15),
          Container(width: 1.5, height: 25, color: Colors.grey[300]),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("PROGRESS", style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w900)),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          if (streak > 0) _buildAnimatedStreakBadge(streak),
          const SizedBox(width: 12),
          _buildCircularProgress(progress),
        ],
      ),
    );
  }

  Widget _buildFullDashboard(int total, int done, int streak, double progress) {
    return Column(
      key: const ValueKey("full"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 20, color: Colors.orange[700]),
                const SizedBox(width: 6),
                const Text("PERFORMANCE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
              ],
            ),
            const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 11,
              child: Container(
                height: 125,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[600]!]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Today's Score", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white24, color: Colors.white, minHeight: 8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 9,
              child: Column(
                children: [
                  _buildDashCard("Streak", "$streak Days", Colors.orange, Icons.local_fire_department_rounded),
                  const SizedBox(height: 10),
                  _buildDashCard("Goal", "$done/$total", Colors.green, Icons.track_changes_rounded),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashCard(String label, String val, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.12), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label.toUpperCase(), style: TextStyle(color: color.withOpacity(0.6), fontSize: 8, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w900)),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildAnimatedStreakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange[400]!, Colors.orange[700]!]), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
        Text(" $streak", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      ]),
    );
  }

// 2. Animated Glow Progress
  Widget _buildCircularProgress(double progress) {
    bool isDone = progress >= 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (isDone) // Background glow when 100%
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                  ],
                ),
              ),
            SizedBox(
              height: 36, width: 36,
              child: CircularProgressIndicator(
                value: value,
                backgroundColor: Colors.grey[200],
                color: isDone ? Colors.green : Colors.blueAccent,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
              ),
            ),
            if (isDone)
              const Icon(Icons.check, size: 18, color: Colors.green),
          ],
        );
      },
    );
  }

  // --- CALENDAR WITH GESTURE TO FULL MONTH ---
 // --- CALENDAR HEADER (Now static, no drag here) ---
  Widget _buildTeamsCalendarHeader() {
    final viewModel = context.watch<TaskViewModel>();
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDate,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false, 
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        onDaySelected: (selectedDay, focusedDay) => setState(() { 
          _selectedDate = selectedDay; 
          _focusedDate = focusedDay; 
        }),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final tasks = viewModel.tasks.where((t) => isSameDay(t.dueDate, date)).toList();
            if (tasks.isEmpty) return null;
            if (tasks.length >= 2) {
              return Positioned(
                right: 4, top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('${tasks.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              );
            }
            return Positioned(bottom: 6, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)));
          },
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // --- THE TOGGLE HANDLE (DRAG AREA) ---
  Widget _buildToggleHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Makes the whole bar area draggable
      onVerticalDragUpdate: (details) {
        // Dragging DOWN expands to Month
        if (details.delta.dy > 5) {
          if (_calendarFormat != CalendarFormat.month) {
            HapticFeedback.lightImpact();
            setState(() => _calendarFormat = CalendarFormat.month);
          }
        } 
        // Dragging UP collapses to Week
        else if (details.delta.dy < -5) {
          if (_calendarFormat != CalendarFormat.week) {
            HapticFeedback.lightImpact();
            setState(() => _calendarFormat = CalendarFormat.week);
          }
        }
      },
      onTap: () {
        // Optional: Still allow tapping the bar to toggle
        HapticFeedback.selectionClick();
        setState(() => _calendarFormat = _calendarFormat == CalendarFormat.week 
          ? CalendarFormat.month 
          : CalendarFormat.week);
      },
      child: Container(
        width: double.infinity, 
        height: 30, // Slightly taller for easier grabbing
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5)
            )
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 45, 
              height: 5, 
              decoration: BoxDecoration(
                color: Colors.grey[300], 
                borderRadius: BorderRadius.circular(10)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfiniteAgenda() {
    return ListView.builder(
      key: ValueKey(_selectedDate),
      itemCount: 365,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final date = _selectedDate.add(Duration(days: index));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(date),
            _buildTaskListForDate(date),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildTaskListForDate(DateTime date) {
    final viewModel = context.watch<TaskViewModel>();
    var dailyTasks = viewModel.tasks.where((t) => isSameDay(t.dueDate, date)).toList();
    if (_hideCompleted) dailyTasks = dailyTasks.where((t) => !t.isCompleted).toList();
    if (dailyTasks.isEmpty) return _buildNoTaskCard("No tasks scheduled");
    return Column(children: dailyTasks.map((task) => _buildTeamsTaskCard(task)).toList());
  }

Widget _buildSectionHeader(DateTime date) {
    bool isToday = isSameDay(date, DateTime.now());
    return ClipRRect(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        // This makes the header feel like it's floating over the content
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FE).withOpacity(0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 4, height: 16,
              decoration: BoxDecoration(
                color: isToday ? Colors.blueAccent : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isToday ? "TODAY" : DateFormat('EEEE').format(date).toUpperCase(),
              style: TextStyle(
                color: isToday ? Colors.blueAccent : Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5
              )
            ),
            const Spacer(),
            Text(
              DateFormat('MMM d').format(date),
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTaskCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Row(children: [Icon(Icons.wb_sunny_outlined, color: Colors.orange[300], size: 20), const SizedBox(width: 12), Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 14))]),
    );
  }

  Widget _buildTeamsTaskCard(Task task) {
    final viewModel = context.read<TaskViewModel>();
    final isCompleted = task.isCompleted;
    String startTime = task.dueDate != null ? DateFormat('h:mm a').format(task.dueDate!) : "9:00 AM";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(task.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(onPressed: (context) => _handleToggle(task), backgroundColor: isCompleted ? Colors.orange : Colors.green, icon: isCompleted ? Icons.undo : Icons.check, label: isCompleted ? 'Undo' : 'Done', borderRadius: BorderRadius.circular(15)),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(onPressed: (context) => viewModel.deleteTask(task.id), backgroundColor: Colors.redAccent, icon: Icons.delete_outline, label: 'Delete', borderRadius: BorderRadius.circular(15)),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: () => _handleToggle(task),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26, height: 26,
                decoration: BoxDecoration(color: isCompleted ? Colors.green : Colors.transparent, border: Border.all(color: isCompleted ? Colors.green : Colors.grey[300]!, width: 2), shape: BoxShape.circle),
                child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            title: Text(task.title, style: TextStyle(fontWeight: FontWeight.w700, color: isCompleted ? Colors.grey : const Color(0xFF2D3142), decoration: isCompleted ? TextDecoration.lineThrough : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description.isNotEmpty) Text(task.description, maxLines: 1, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [Icon(Icons.access_time, size: 14, color: Colors.blue[400]), const SizedBox(width: 4), Text(startTime, style: TextStyle(color: Colors.blue[400], fontWeight: FontWeight.w600, fontSize: 12))]),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0E0E0)),
          ),
        ),
      ),
    );
  }

  void _handleToggle(Task task) {
    final viewModel = context.read<TaskViewModel>();
    HapticFeedback.mediumImpact();

    // 1. Capture the ID and the CURRENT completion status before toggling
    final String taskId = task.id;
    final bool wasCompleted = task.isCompleted;

    // 2. Perform the toggle
    viewModel.toggleTaskCompletion(task);

    // 3. We ONLY want to celebrate if the user JUST marked it as 'Done'
    // If wasCompleted was false, it means it is NOW true.
    if (!wasCompleted) {
      // We wait for the end of the frame to make sure the ViewModel has finished 
      // updating all its internal lists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Get the fresh list of tasks from the viewModel
        final updatedTasks = viewModel.tasks.where((t) => isSameDay(t.dueDate, _selectedDate)).toList();
        
        // Check if there are tasks and if EVERY SINGLE ONE is now completed
        bool isDayPerfect = updatedTasks.isNotEmpty && updatedTasks.every((t) => t.isCompleted);

        if (isDayPerfect) {
          int newStreak = _calculateStreak(viewModel.tasks);
          _triggerCelebration(newStreak);
        }
      });
    }
  }
}