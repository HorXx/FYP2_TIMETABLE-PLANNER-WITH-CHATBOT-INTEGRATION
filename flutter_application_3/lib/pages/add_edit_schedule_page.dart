import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart' as task_provider;
import 'timetable_page.dart';
import '../providers/category_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class EditTaskPage extends StatefulWidget {
  final task_provider.Task? task; // null 表示新建，否则为编辑
  final String? initialTitle;
  final DateTime? initialDateTime;
  final String? initialNotes;
  final String? initialCategory;
  final bool hideDueDate;
  final bool isTravel;

  const EditTaskPage({
    Key? key,
    this.task,
    this.initialTitle,
    this.initialDateTime,
    this.initialNotes,
    this.initialCategory,
    this.hideDueDate = false,
    this.isTravel = false,
  }) : super(key: key);

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _category = 'None';
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = TimeOfDay.now();
  bool _remind = false;
  int _progress = 0;
  DateTime _startDateTime = DateTime.now();
  DateTime _endDateTime = DateTime.now().add(Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descController.text = widget.task!.description;
      _remind = widget.task!.remind;
      _category = widget.task!.category;
      _progress = widget.task!.progress;
      if (widget.task!.isTravel) {
        // travel 任务
        _startDateTime = widget.task!.startDate ?? DateTime.now();
        _endDateTime = widget.task!.endDate ?? DateTime.now().add(Duration(hours: 1));
      } else {
        // 普通任务
        _dueDate = widget.task!.date ?? DateTime.now();
        // Parse time string to TimeOfDay
        try {
          final timeParts = widget.task!.time.split(' ');
          if (timeParts.length == 2) {
            final time = timeParts[0].split(':');
            final hour = int.parse(time[0]);
            final minute = int.parse(time[1]);
            final isAm = timeParts[1].toUpperCase() == 'AM';
            _dueTime = TimeOfDay(
              hour: isAm ? (hour == 12 ? 0 : hour) : (hour == 12 ? 12 : hour + 12),
              minute: minute,
            );
          }
        } catch (e) {
          print('Error parsing time string: \\${e}');
          _dueTime = TimeOfDay.now();
        }
      }
    } else if (widget.initialTitle != null || widget.initialDateTime != null || widget.initialNotes != null || widget.initialCategory != null) {
      _titleController.text = widget.initialTitle ?? '';
      _descController.text = widget.initialNotes ?? '';
      if (widget.initialDateTime != null) {
        _dueDate = widget.initialDateTime!;
        _dueTime = TimeOfDay(
          hour: widget.initialDateTime!.hour,
          minute: widget.initialDateTime!.minute,
        );
        _startDateTime = widget.initialDateTime!;
        _endDateTime = widget.initialDateTime!.add(Duration(hours: 1));
      }
      if (widget.initialCategory != null) {
        _category = widget.initialCategory!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final provider = Provider.of<task_provider.TaskProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.task == null ? 'New Task' : 'Edit Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[50],
        elevation: 0,
        actions: [
          if (widget.task != null)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Task',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Task'),
                    content: Text('Are you sure you want to delete this task?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await provider.removeTask(widget.task!.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Task Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(hintText: 'Enter Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 20),
              Text('Select Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final uniqueCategories = categoryProvider.categories.toSet().toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in uniqueCategories)
                        _buildCategoryButton(cat, key: ValueKey('cat_$cat')),
                      _buildCreateCategoryButton(categoryProvider),
                    ],
                  );
                },
              ),
              SizedBox(height: 20),
              Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                minLines: 2,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(hintText: 'Type something...'),
              ),
              SizedBox(height: 16),
              if (!widget.hideDueDate && !widget.isTravel) ...[
                _buildDateTimePickers(context),
                SizedBox(height: 20),
              ],
              if (widget.isTravel) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDateTime,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_startDateTime),
                                );
                                if (time != null) {
                                  setState(() {
                                    _startDateTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                                  });
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_startDateTime.year}-${_startDateTime.month.toString().padLeft(2, '0')}-${_startDateTime.day.toString().padLeft(2, '0')}  ${TimeOfDay.fromDateTime(_startDateTime).format(context)}',
                                style: TextStyle(fontSize: 16),
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('End', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDateTime,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(_endDateTime),
                                );
                                if (time != null) {
                                  setState(() {
                                    _endDateTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                                  });
                                }
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_endDateTime.year}-${_endDateTime.month.toString().padLeft(2, '0')}-${_endDateTime.day.toString().padLeft(2, '0')}  ${TimeOfDay.fromDateTime(_endDateTime).format(context)}',
                                style: TextStyle(fontSize: 16),
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
              Text('Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              SizedBox(height: 6),
              Slider(
                value: _progress.toDouble(),
                min: 0,
                max: 100,
                divisions: 4, // For 0%, 25%, 50%, 75%, 100%
                label: '${_progress.round()}%',
                onChanged: (double value) {
                  setState(() {
                    _progress = value.round();
                  });
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue[300],
                  minimumSize: Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _onSave,
                child: Text('Save', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String label, {Key? key}) {
    final selected = _category == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = label),
        selectedColor: Colors.lightBlue[200],
      ),
    );
  }

  Widget _buildCreateCategoryButton(CategoryProvider categoryProvider) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 18, color: Colors.blue),
          SizedBox(width: 4),
          Text('Create', style: TextStyle(color: Colors.blue)),
        ],
      ),
      selected: false,
      onSelected: (_) => _showCreateCategoryDialog(categoryProvider),
      backgroundColor: Colors.blue[50],
      shape: StadiumBorder(side: BorderSide(color: Colors.blue)),
    );
  }

  void _showCreateCategoryDialog(CategoryProvider categoryProvider) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              final uid = FirebaseAuth.instance.currentUser?.uid;
              print('Create category: $name, uid: $uid');
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please login first!')),
                );
                return;
              }
              if (name.isEmpty) return;
              if (categoryProvider.categories.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category already exists!')),
                );
                return;
              }
              try {
                await categoryProvider.addCategory(name);
                setState(() {
                  _category = name;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category added successfully!')),
                );
                Navigator.pop(context, name);
              } catch (e) {
                print('Add category error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add category: $e')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _category = result;
      });
    }
  }

  Widget _buildDateTimePickers(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(width: 8),
                    Text('Due Date'),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time),
                    SizedBox(width: 8),
                    Text('Time'),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.alarm),
                    SizedBox(width: 8),
                    Text('Reminder'),
                  ],
                ),
              ],
            ),
            Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: Text('${_dueDate.toLocal()}'.split(' ')[0]),
                  style: TextButton.styleFrom(backgroundColor: Colors.blue[50]),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _dueTime,
                    );
                    if (picked != null) setState(() => _dueTime = picked);
                  },
                  child: Text(
                    '${_dueDate.month}月${_dueDate.day},${_dueDate.year}  ${_dueTime.format(context)}',
                    style: TextStyle(overflow: TextOverflow.visible),
                  ),
                  style: TextButton.styleFrom(backgroundColor: Colors.blue[50]),
                ),
                SizedBox(height: 8),
                Switch(
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _onSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      final provider = Provider.of<task_provider.TaskProvider>(context, listen: false);
      if (widget.isTravel) {
        // travel 任务只存一条
        final start = _startDateTime ?? DateTime.now();
        final end = _endDateTime ?? DateTime.now();
        final task = task_provider.Task(
          id: widget.task?.id ?? '',
          title: _titleController.text,
          time: '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(start).format(context)} ~ '
                '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(end).format(context)}',
          remind: _remind,
          startDate: start,
          endDate: end,
          isTravel: true,
          category: _category,
          description: _descController.text,
          progress: _progress,
        );
        if (widget.task == null) {
          await provider.addTask(task);
        } else {
          await provider.updateTask(task);
        }
      } else {
        // 普通任务
        final task = task_provider.Task(
          id: widget.task?.id ?? '',
          title: _titleController.text,
          time: _dueTime.format(context),
          remind: _remind,
          date: DateTime(
            _dueDate.year, _dueDate.month, _dueDate.day,
            _dueTime.hour, _dueTime.minute,
          ),
          isTravel: false,
          category: _category,
          description: _descController.text,
          progress: _progress,
        );
        if (widget.task == null) {
          await provider.addTask(task);
        } else {
          await provider.updateTask(task);
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  DateTime get _startDateTimeSafe => _startDateTime ?? DateTime.now();
  DateTime get _endDateTimeSafe => _endDateTime ?? DateTime.now();
} 