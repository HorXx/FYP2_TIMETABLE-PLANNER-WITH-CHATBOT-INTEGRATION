import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/task_provider.dart' as task_provider;
import 'add_edit_schedule_page.dart';
import '../widgets/phone_frame.dart';
import '../widgets/reminder_dialog.dart';
import 'dart:async'; // Import dart:async for StreamSubscription
import 'package:firebase_auth/firebase_auth.dart';

class Task {
  final String title;
  final String time;
  final bool remind;
  final String category;
  Task({required this.title, required this.time, required this.remind, required this.category});
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => TimetablePageState();
}

class TimetablePageState extends State<TimetablePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<DateTime> _getCurrentWeekDays() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i));
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule', style: TextStyle(color: Theme.of(context).primaryColor)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.black54,
          tabs: [
            Tab(text: 'Day View'),
            Tab(text: 'Week View'),
            Tab(text: 'Month View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDayView(context, taskProvider),
          _buildWeekView(context, taskProvider),
          _buildMonthView(context, taskProvider),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_edit');
        },
        backgroundColor: Theme.of(context).primaryColor,
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
        selectedItemColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildDayView(BuildContext context, task_provider.TaskProvider taskProvider) {
    final today = DateTime.now();
    return StreamBuilder<List<task_provider.Task>>(
      stream: taskProvider.getTasksForDay(today),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data ?? [];

        // Sort tasks: incomplete tasks first, then completed tasks
        tasks.sort((a, b) {
          DateTime aDate = a.isTravel ? (a.startDate ?? DateTime(2100)) : (a.date ?? DateTime(2100));
          DateTime bDate = b.isTravel ? (b.startDate ?? DateTime(2100)) : (b.date ?? DateTime(2100));
          if (a.progress < 100 && b.progress == 100) return -1;
          if (a.progress == 100 && b.progress < 100) return 1;
          return aDate.compareTo(bDate);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Tasks List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(child: Text('No tasks for today.'))
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) => SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
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
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(task.title,
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    color: Theme.of(context).primaryColor,
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
                                                    task.category == 'Travel'
                                                      ? _formatTravelDate(task.time)
                                                      : displayDate(task),
                                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (task.remind) ...[
                                                  SizedBox(width: 12),
                                                  Icon(Icons.alarm, size: 16, color: Theme.of(context).primaryColor),
                                                ]
                                              ],
                                            ),
                                          ],
                                        ),
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
                                      color: Theme.of(context).primaryColor.withOpacity(0.8),
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
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekView(BuildContext context, task_provider.TaskProvider taskProvider) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _selectedDay,
          calendarFormat: CalendarFormat.week,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
            });
          },
          availableCalendarFormats: const {CalendarFormat.week: 'Week'},
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<task_provider.Task>>(
            stream: taskProvider.getTasksForDay(_selectedDay),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];

              // Sort tasks: incomplete tasks first, then completed tasks
              tasks.sort((a, b) {
                DateTime aDate = a.isTravel ? (a.startDate ?? DateTime(2100)) : (a.date ?? DateTime(2100));
                DateTime bDate = b.isTravel ? (b.startDate ?? DateTime(2100)) : (b.date ?? DateTime(2100));
                if (a.progress < 100 && b.progress == 100) return -1;
                if (a.progress == 100 && b.progress < 100) return 1;
                return aDate.compareTo(bDate);
              });

              if (tasks.isEmpty) {
                return Center(child: Text('No tasks for this day.'));
              }
              return ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: tasks.length,
                separatorBuilder: (context, index) => SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final task = tasks[index];
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
                                        color: Theme.of(context).primaryColor,
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
                                        task.category == 'Travel'
                                          ? _formatTravelDate(task.time)
                                          : displayDate(task),
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (task.remind) ...[
                                      SizedBox(width: 12),
                                      Icon(Icons.alarm, size: 16, color: Theme.of(context).primaryColor),
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
                                color: Theme.of(context).primaryColor.withOpacity(0.8),
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
    );
  }

  Widget _buildMonthView(BuildContext context, task_provider.TaskProvider taskProvider) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _selectedDay,
          calendarFormat: CalendarFormat.month,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
            });
          },
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<task_provider.Task>>(
            stream: taskProvider.getTasksForDay(_selectedDay),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];

              // Sort tasks: incomplete tasks first, then completed tasks
              tasks.sort((a, b) {
                DateTime aDate = a.isTravel ? (a.startDate ?? DateTime(2100)) : (a.date ?? DateTime(2100));
                DateTime bDate = b.isTravel ? (b.startDate ?? DateTime(2100)) : (b.date ?? DateTime(2100));
                if (a.progress < 100 && b.progress == 100) return -1;
                if (a.progress == 100 && b.progress < 100) return 1;
                return aDate.compareTo(bDate);
              });

              if (tasks.isEmpty) {
                return Center(child: Text('No tasks for this day.'));
              }
              return ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: tasks.length,
                separatorBuilder: (context, index) => SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final task = tasks[index];
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
                                        color: Theme.of(context).primaryColor,
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
                                        task.category == 'Travel'
                                          ? _formatTravelDate(task.time)
                                          : displayDate(task),
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (task.remind) ...[
                                      SizedBox(width: 12),
                                      Icon(Icons.alarm, size: 16, color: Theme.of(context).primaryColor),
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
                                color: Theme.of(context).primaryColor.withOpacity(0.8),
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