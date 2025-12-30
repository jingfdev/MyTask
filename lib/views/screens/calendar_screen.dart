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
  const CalendarScreen({super.key});

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
  // --- High Energy / Productivity ---
  {"title": "Daily Champion!", "msg": "You've crushed every single task today.", "icon": "🏆", "color": Colors.orangeAccent.withValues(alpha: 0.9)},
  {"title": "Unstoppable!", "msg": "Perfect day completed!", "icon": "🚀", "color": Colors.blueAccent},
  {"title": "Victory!", "msg": "All items checked. Great focus!", "icon": "⭐", "color": Colors.purpleAccent},
  {"title": "Productivity King!", "msg": "You made that look easy.", "icon": "👑", "color": Colors.amber},
  {"title": "Task Slayer!", "msg": "Everything on the list is gone.", "icon": "⚔️", "color": Colors.redAccent},
  {"title": "God Mode!", "msg": "Is there anything you can't do?", "icon": "⚡", "color": Colors.cyanAccent},

  // --- Zen / Calm / Satisfying ---
  {"title": "Clean Sweep!", "msg": "A perfectly empty list. So satisfying.", "icon": "🧹", "color": Colors.tealAccent},
  {"title": "Pure Focus!", "msg": "You were in the zone today.", "icon": "🧘", "color": Colors.lightGreenAccent},
  {"title": "Mind Like Water", "msg": "You handled everything with ease.", "icon": "🌊", "color": Colors.blue},
  {"title": "Well Deserved Rest", "msg": "Day finished. Time to unplug.", "icon": "🌙", "color": Colors.indigoAccent},

  // --- Fun / Playful ---
  {"title": "Boom Shakalaka!", "msg": "You're on fire today!", "icon": "🔥", "color": Colors.deepOrange},
  {"title": "Level Up!", "msg": "Your productivity stats just peaked.", "icon": "🎮", "color": Colors.greenAccent},
  {"title": "Checkmate!", "msg": "You played today perfectly.", "icon": "♟️", "color": Colors.blueGrey},
  {"title": "Bullseye!", "msg": "Hit every single target on the list.", "icon": "🎯", "color": Colors.red},
  {"title": "Magic Touch!", "msg": "How do you get so much done?", "icon": "🪄", "color": Colors.pinkAccent},

  // --- Short & Punchy ---
  {"title": "Flawless!", "msg": "100% completion achieved.", "icon": "💎", "color": Colors.lightBlueAccent},
  {"title": "Beast Mode", "msg": "List: 0 | You: 1", "icon": "🦁", "color": Colors.brown},
  {"title": "Done & Dusted", "msg": "See you tomorrow!", "icon": "✅", "color": Colors.green},
  {"title": "Legendary!", "msg": "That's how you get things done.", "icon": "🏅", "color": Colors.orange},
  {"title": "Mission Complete", "msg": "Returning to base for rest.", "icon": "🚁", "color": Colors.deepPurpleAccent.withValues(alpha: 0.9)},
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
  // Select a random celebration theme from your list of 20
  final random = (List.from(_celebrations)..shuffle()).first;
  final Color themeColor = random['color'];

  _confettiController.play();
  HapticFeedback.vibrate();

  showDialog(
    context: context,
    barrierDismissible: false, // Force them to see their glory!
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. The Streak Badge (Only shows if they have a streak)
          if (updatedStreak > 1)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: ShapeDecoration(
                gradient: LinearGradient(colors: [themeColor, themeColor.withValues(alpha: 0.6)]),
                shape: const StadiumBorder()
              ),
              child: Text(
                "🔥 $updatedStreak DAY STREAK",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
              ),
            ),

          // 2. The Big Icon with a subtle glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              Text(random['icon'], style: const TextStyle(fontSize: 55)),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Title & Message
          Text(
            random['title'],
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: themeColor),
          ),
          const SizedBox(height: 12),
          Text(
            random['msg'],
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.4),
          ),

          const SizedBox(height: 30),

          // 4. Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _confettiController.stop();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              child: const Text(
                "Keep it up!",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
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
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text("New Task", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(DateFormat('MMM dd').format(_selectedDate),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: "What needs to be done?",
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              ),
              TextField(
                controller: descController,
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                decoration: InputDecoration(
                  hintText: "Add notes (optional)",
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
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
                        viewModel.addTask(Task(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text,
                          description: descController.text,
                          isCompleted: false,
                          createdAt: DateTime.now(),
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: Text('My Schedule', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 22)),
            actions: [
              IconButton(
                icon: Icon(_hideCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _hideCompleted ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
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

  Widget _buildQuickStatsRow() {
    final viewModel = context.watch<TaskViewModel>();
    final dayTasks = viewModel.tasks.where((t) => isSameDay(t.dueDate, _selectedDate)).toList();
    final completedCount = dayTasks.where((t) => t.isCompleted).length;
    int streak = _calculateStreak(viewModel.tasks);
    double progress = dayTasks.isEmpty ? 0 : completedCount / dayTasks.length;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 5) setState(() => _isDashboardExpanded = true);
        if (details.delta.dy < -5) setState(() => _isDashboardExpanded = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        height: _isDashboardExpanded ? 240 : 90,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          _buildStatItem("TASKS", "$done/$total", Colors.blueAccent),
          const SizedBox(width: 15),
          Container(width: 1.5, height: 25, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("PROGRESS", style: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w900)),
              Text("${(progress * 100).toInt()}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
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
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 20, color: Colors.orange[700]),
                const SizedBox(width: 6),
                Text("PERFORMANCE",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
            const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
          ],
        ),
        const SizedBox(height: 12), // Increased spacing

        // Main Content Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BLUE BOX: Spans Col 1 & 2 across both rows
            Expanded(
              flex: 2, // Takes up 2/3 of the width
              child: Container(
                height: 140, // Explicit height to match the stack on the right
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[900]!, Colors.blue[600]!],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today's Score",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text("${(progress * 100).toInt()}%",
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 42, fontWeight: FontWeight.w900)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.24),
                        color: Theme.of(context).colorScheme.onPrimary,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12), // Gap between Blue and the stack

            // RIGHT SIDE: Stacked Streak and Goal
            Expanded(
              flex: 1, // Takes up 1/3 of the width
              child: SizedBox(
                height: 135, // Must match the blue box height exactly
                child: Column(
                  children: [
                    // YELLOW BOX (Row 1, Col 3)
                    Expanded(
                      child: _buildDashCard(
                        "Streak",
                        "$streak Days",
                        Colors.orange,
                        Icons.local_fire_department_rounded
                      ),
                    ),
                    const SizedBox(height: 10), // Gap between yellow and green
                    // GREEN BOX (Row 2, Col 3)
                    Expanded(
                      child: _buildDashCard(
                        "Goal",
                        "$done/$total",
                        Colors.green,
                        Icons.track_changes_rounded
                      ),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color), // Smaller icon
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 7, // Smaller font
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // FittedBox prevents the "Overflow" by scaling the text down
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 15, // Slightly smaller base font
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w900)),
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

  Widget _buildCircularProgress(double progress) {
    bool isDone = progress >= 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (isDone)
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)
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

  Widget _buildTeamsCalendarHeader() {
    final viewModel = context.watch<TaskViewModel>();
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
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
          todayDecoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildToggleHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 5) {
          if (_calendarFormat != CalendarFormat.month) {
            HapticFeedback.lightImpact();
            setState(() => _calendarFormat = CalendarFormat.month);
          }
        }
        else if (details.delta.dy < -5) {
          if (_calendarFormat != CalendarFormat.week) {
            HapticFeedback.lightImpact();
            setState(() => _calendarFormat = CalendarFormat.week);
          }
        }
      },
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _calendarFormat = _calendarFormat == CalendarFormat.week
          ? CalendarFormat.month
          : CalendarFormat.week);
      },
      child: Container(
        width: double.infinity,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 16,
            decoration: BoxDecoration(
              color: isToday ? Colors.blueAccent : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
    );
  }

  Widget _buildNoTaskCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1))),
      child: Row(children: [Icon(Icons.wb_sunny_outlined, color: Colors.orange[300], size: 20), const SizedBox(width: 12), Text(message, style: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5), fontSize: 14))]),
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

        // LEFT SIDE SWIPE (DONE)
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25, // Adjust width of the button
          children: [
            SlidableAction(
              onPressed: (context) => _handleToggle(task),
              backgroundColor: isCompleted ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              icon: isCompleted ? Icons.undo : Icons.check,
              label: isCompleted ? 'Undo' : 'Done',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ],
        ),

        // RIGHT SIDE SWIPE (TOMORROW + DELETE)
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5, // Larger ratio to fit two buttons
          children: [
            // MOVE TO TOMORROW BUTTON
            SlidableAction(
              onPressed: (context) {
                final nextDay = task.dueDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1));
                viewModel.updateTask(task.copyWith(dueDate: nextDay));
                HapticFeedback.mediumImpact();
              },
              backgroundColor: Colors.amber[600]!,
              foregroundColor: Colors.white,
              icon: Icons.auto_awesome_motion_rounded,
              label: 'Tomorrow',
            ),
            // DELETE BUTTON
            SlidableAction(
              onPressed: (context) => viewModel.deleteTask(task.id),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: () => _handleToggle(task),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26, height: 26,
                decoration: BoxDecoration(color: isCompleted ? Colors.green : Colors.transparent, border: Border.all(color: isCompleted ? Colors.green : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 2), shape: BoxShape.circle),
                child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            // THE NEW ANIMATED TITLE
            title: AnimatedStrikethroughText(
              text: task.title,
              isCompleted: isCompleted,
            ),
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

    final bool wasCompleted = task.isCompleted;
    viewModel.toggleTaskCompletion(task);

    if (!wasCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final updatedTasks = viewModel.tasks.where((t) => isSameDay(t.dueDate, _selectedDate)).toList();
        bool isDayPerfect = updatedTasks.isNotEmpty && updatedTasks.every((t) => t.isCompleted);

        if (isDayPerfect) {
          int newStreak = _calculateStreak(viewModel.tasks);
          _triggerCelebration(newStreak);
        }
      });
    }
  }
}

// 3. THE "PREMIUM" STRIKETHROUGH WIDGET
class AnimatedStrikethroughText extends StatelessWidget {
  final String text;
  final bool isCompleted;

  const AnimatedStrikethroughText({
    super.key,
    required this.text,
    required this.isCompleted,
  }) : super();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isCompleted ? Colors.grey[400] : const Color(0xFF2D3142),
          ),
        ),
        // This draws the line across the text
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              width: isCompleted ? 1000 : 0, // Slides across the whole width
              height: 1.5,
              color: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }
}