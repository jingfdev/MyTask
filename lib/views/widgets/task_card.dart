import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mytask_project/models/task.dart';
import 'package:mytask_project/viewmodels/task_viewmodel.dart';
import 'package:intl/intl.dart';

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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () {
                context.read<TaskViewModel>().toggleTaskCompletion(task);
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.isCompleted
                        ? Colors.blue[600]!
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  color: task.isCompleted ? Colors.blue[600] : Colors.white,
                ),
                child: task.isCompleted
                    ? Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(width: 16),
            // Task Title and Category
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
                  SizedBox(height: 8),
                  // Category Tag
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(task.category)[0],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.category,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _getCategoryColor(task.category)[1],
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Delete Button
            GestureDetector(
              onTap: () {
                _showDeleteDialog(context);
              },
              child: Icon(Icons.close, color: Colors.grey[400], size: 20),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return [Color(0xFFE3F2FD), Color(0xFF1976D2)];
      case 'personal':
        return [Color(0xFFF3E5F5), Color(0xFF7B1FA2)];
      case 'shopping':
        return [Color(0xFFFFF3E0), Color(0xFFF57C00)];
      default:
        return [Color(0xFFF5F5F5), Color(0xFF616161)];
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Task?'),
        content: Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskViewModel>().deleteTask(task.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
