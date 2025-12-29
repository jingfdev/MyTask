import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
// PATH FIXED HERE:
import 'package:mytask_project/views/screens/task_form_page.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<TaskViewModel>();
    String formattedTime = task.dueDate != null
        ? DateFormat('hh:mm a').format(task.dueDate!)
        : 'No Time';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Slidable(
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (context) => viewModel.deleteTask(task.id),
                backgroundColor: Colors.red[400]!,
                foregroundColor: Colors.white,
                icon: Icons.delete_rounded,
                label: 'Delete',
              ),
            ],
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TaskFormPage(task: task)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: task.isCompleted ? Colors.green[400]! : Colors.blue[600]!, width: 6)),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => viewModel.toggleTaskCompletion(task),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: task.isCompleted ? Colors.green[400] : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: task.isCompleted ? Colors.green[400]! : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 2),
                        ),
                        child: task.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: task.isCompleted ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.5) : Theme.of(context).colorScheme.onSurface, decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(task.description, maxLines: 1, style: TextStyle(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4), fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    if (task.dueDate != null) _buildTimeBadge(context, formattedTime),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBadge(BuildContext context, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1))),
      child: Text(time, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
