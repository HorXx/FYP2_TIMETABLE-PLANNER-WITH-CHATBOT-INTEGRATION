import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../pages/add_edit_schedule_page.dart';
import '../widgets/phone_frame.dart';

class ReminderDialog extends StatefulWidget {
  final List<Task> tasks;
  final int initialPage;
  const ReminderDialog({Key? key, required this.tasks, this.initialPage = 0}) : super(key: key);

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late PageController _pageController;
  late List<int> _progressList;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _progressList = widget.tasks.map((t) => t.progress).toList();
    _currentPage = widget.initialPage;
  }

  Widget _buildProgressButton(int progress, int pageIndex) {
    final isSelected = _progressList[pageIndex] == progress;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size(0, 36),
      ),
      onPressed: () {
        setState(() {
          _progressList[pageIndex] = progress;
        });
      },
      child: Text('$progress%'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Task Reminder'),
      content: SizedBox(
        width: 320,
        height: 320,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.tasks.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, i) {
            final task = widget.tasks[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Task: ${task.title}'),
                SizedBox(height: 8),
                Text('Due Date: ${displayDate(task)}'),
                SizedBox(height: 8),
                Text('Due Time: ${task.time}'),
                SizedBox(height: 16),
                Text('Update Progress:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildProgressButton(0, i),
                    _buildProgressButton(25, i),
                    _buildProgressButton(50, i),
                    _buildProgressButton(75, i),
                    _buildProgressButton(100, i),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Edit Details'),
          onPressed: () {
            final task = widget.tasks[_currentPage];
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhoneFrame(child: EditTaskPage(task: task)),
              ),
            );
          },
        ),
        ElevatedButton(
          child: Text('Save Progress'),
          onPressed: () {
            final taskProvider = Provider.of<TaskProvider>(context, listen: false);
            final task = widget.tasks[_currentPage];
            final updatedTask = Task(
              id: task.id,
              title: task.title,
              time: task.time,
              remind: task.remind,
              date: task.date,
              category: task.category,
              description: task.description,
              progress: _progressList[_currentPage],
            );
            taskProvider.updateTask(updatedTask).then((_) {
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/home');
            }).catchError((error) {
              print('Error updating task progress: $error');
              if (!mounted) return;
              Navigator.of(context).pop();
            });
          },
        ),
      ],
    );
  }
}

String displayDate(Task task) {
  if (task.isTravel) {
    final start = task.startDate;
    final end = task.endDate;
    if (start != null && end != null) {
      return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ~ '
             '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    } else {
      return 'Travel';
    }
  } else if (task.date != null) {
    return '${task.date!.year}-${task.date!.month.toString().padLeft(2, '0')}-${task.date!.day.toString().padLeft(2, '0')}';
  } else {
    return '';
  }
} 