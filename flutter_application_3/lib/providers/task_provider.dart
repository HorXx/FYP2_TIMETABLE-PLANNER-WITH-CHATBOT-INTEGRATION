import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Task {
  final String id;
  final String title;
  final String time;
  final bool remind;
  final DateTime? date; // 普通任务用
  final DateTime? startDate; // travel 任务用
  final DateTime? endDate;   // travel 任务用
  final bool isTravel;
  final String category;
  final String description;
  final int progress;
  final bool reminderShown;

  Task({
    required this.id,
    required this.title,
    required this.time,
    required this.remind,
    this.date,
    this.startDate,
    this.endDate,
    this.isTravel = false,
    this.category = 'None',
    this.description = '',
    this.progress = 0,
    this.reminderShown = false,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      remind: data['remind'] ?? false,
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : null,
      startDate: data['startDate'] != null ? (data['startDate'] as Timestamp).toDate() : null,
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      isTravel: data['isTravel'] ?? false,
      category: data['category'] ?? 'None',
      description: data['description'] ?? '',
      progress: data['progress'] ?? 0,
      reminderShown: data['reminderShown'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'time': time,
      'remind': remind,
      if (date != null) 'date': date,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      'isTravel': isTravel,
      'category': category,
      'description': description,
      'progress': progress,
      'reminderShown': reminderShown,
    };
  }
}

class TaskProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _tasksRef {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(user.uid).collection('tasks');
  }

  Stream<List<Task>> getTasksForDay(DateTime day) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);
    try {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(Duration(days: 1));
      // 查询所有当天的普通任务和覆盖当天的travel任务
      return _tasksRef
          .snapshots()
          .map((snapshot) {
            final allTasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
            return allTasks.where((task) {
              if (task.isTravel && task.startDate != null && task.endDate != null) {
                final d = normalize(day);
                final s = normalize(task.startDate!);
                final e = normalize(task.endDate!);
                return !d.isBefore(s) && !d.isAfter(e);
              } else {
                final d = normalize(day);
                final t = task.date != null ? normalize(task.date!) : null;
                return t != null && t == d;
              }
            }).toList();
          });
    } catch (e) {
      print('Error getting tasks: $e');
      return Stream.value([]);
    }
  }

  Stream<List<Task>> getTasksInRange(DateTime start, DateTime end) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    try {
      return _tasksRef
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
    } catch (e) {
      print('Error getting tasks in range: $e');
      return Stream.value([]);
    }
  }

  Future<void> addTask(Task task) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    try {
      await _tasksRef.add(task.toMap());
    } catch (e) {
      print('Error adding task: $e');
      throw e;
    }
  }

  Future<void> removeTask(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    try {
      await _tasksRef.doc(id).delete();
    } catch (e) {
      print('Error removing task: $e');
      throw e;
    }
  }

  Future<void> updateTask(Task task) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    try {
      await _tasksRef.doc(task.id).update(task.toMap());
    } catch (e) {
      print('Error updating task: $e');
      throw e;
    }
  }

  Future<List<Task>> getTasksByTravelId(String travelId) async {
    final user = _auth.currentUser;
    if (user == null) return [];
    try {
      final snapshot = await _tasksRef.where('travelId', isEqualTo: travelId).get();
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting tasks by travelId: $e');
      return [];
    }
  }
} 