import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/edit-task',
          arguments: task,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Completion toggle
            GestureDetector(
              onTap: () {
                context.read<TaskViewModel>().updateTask(
                  Task(
                    id: task.id,
                    title: task.title,
                    description: task.description,
                    isCompleted: !task.isCompleted,
                    createdAt: task.createdAt,
                    dueDate: task.dueDate,
                  ),
                );
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.isCompleted
                        ? Colors.blue
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  color: task.isCompleted
                      ? Colors.blue
                      : Colors.white,
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check,
                    size: 14, color: Colors.white)
                    : null,
              ),
            ),

            const SizedBox(width: 16),

            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: task.isCompleted
                          ? Colors.grey[400]
                          : Colors.black87,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  if (task.dueDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Due ${DateFormat('MMM dd, yyyy').format(task.dueDate!)}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Delete
            GestureDetector(
              onTap: () => _showDeleteDialog(context),
              child: Icon(Icons.close,
                  color: Colors.grey[400], size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content:
        const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskViewModel>().deleteTask(task.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
