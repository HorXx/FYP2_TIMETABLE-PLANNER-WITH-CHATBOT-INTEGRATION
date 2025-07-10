import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart' as task_provider;
import '../providers/category_provider.dart';
import 'timetable_page.dart';
import 'add_edit_schedule_page.dart';
import '../widgets/phone_frame.dart';
import '../widgets/reminder_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return 'User';
    return user!.email!.split('@')[0];
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return Colors.blueAccent;
      case 'Personal':
        return Colors.green;
      case 'Wishlist':
        return Colors.purple;
      case 'None':
      default:
        return Colors.grey;
    }
  }

  String _formatTravelDate(String timeStr) {
    final parts = timeStr.split('~');
    if (parts.length == 2) {
      final start = parts[0].trim().split(' ')[0];
      final end = parts[1].trim().split(' ')[0];
      return start == end ? start : '$start ~ $end';
    }
    return timeStr.split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Please login first.')),
      );
    }
    final navProvider = Provider.of<NavigationProvider>(context);
    final taskProvider = Provider.of<task_provider.TaskProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final today = DateTime.now();
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: Text('Home', style: TextStyle(color: primaryColor)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            Text(
              'Good morning, ${_getUserName()}!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
              textAlign: TextAlign.left,
            ),
            SizedBox(height: 24),
            Builder(
              builder: (context) {
                final uniqueCategories = categoryProvider.categories.toSet().toList();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        key: ValueKey('All'),
                        label: Text('All'),
                        selected: _selectedCategory == 'All',
                        onSelected: (_) => setState(() => _selectedCategory = 'All'),
                      ),
                      for (final cat in uniqueCategories)
                        if (cat != 'None')
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ChoiceChip(
                              key: ValueKey('cat_$cat'),
                              label: Text(cat),
                              selected: _selectedCategory == cat,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                            ),
                          ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Text(
              'Task List',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<task_provider.Task>>(
                stream: taskProvider.getTasksForDay(today),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final todayTasks = snapshot.data ?? [];
                  final filteredTasks = _selectedCategory == 'All'
                      ? todayTasks
                      : todayTasks.where((task) => task.category == _selectedCategory).toList();

                  // Sort tasks: incomplete tasks first, then completed tasks
                  filteredTasks.sort((a, b) {
                    DateTime aDate = a.isTravel ? (a.startDate ?? DateTime(2100)) : (a.date ?? DateTime(2100));
                    DateTime bDate = b.isTravel ? (b.startDate ?? DateTime(2100)) : (b.date ?? DateTime(2100));
                    if (a.progress < 100 && b.progress == 100) return -1;
                    if (a.progress == 100 && b.progress < 100) return 1;
                    return aDate.compareTo(bDate);
                  });

                  return filteredTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_note, size: 80, color: Colors.grey[300]),
                              SizedBox(height: 16),
                              Text('No tasks for today.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredTasks.length,
                          separatorBuilder: (context, index) => SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhoneFrame(
                                      child: EditTaskPage(
                                        task: task,
                                        hideDueDate: task.category == 'Travel',
                                        isTravel: task.category == 'Travel',
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 2,
                                color: task.progress == 100 ? Colors.lightGreen.shade100 : Colors.white,
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(task.title,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                  decoration: task.progress == 100 ? TextDecoration.lineThrough : TextDecoration.none,
                                                  decorationColor: Colors.black87,
                                              )),
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  displayDate(task),
                                                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (task.remind) ...[
                                                SizedBox(width: 12),
                                                Icon(Icons.alarm, size: 16, color: primaryColor),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${task.progress}%',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_edit');
        },
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navProvider.currentIndex,
        onTap: (index) {
          navProvider.setIndex(index);
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/timetable');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/chatbot');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/settings');
              break;
          }
        },
        selectedItemColor: primaryColor,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  String displayDate(task_provider.Task task) {
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
} 