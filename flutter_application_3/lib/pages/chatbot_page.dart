import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../models/message.dart';
import '../models/schedule_data.dart';
import '../services/gpt_service.dart';
import 'add_edit_schedule_page.dart';
import '../widgets/phone_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GPTService _gptService = GPTService();
  bool _isLoading = false;
  List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _messages = [];
          });
        }
        return;
      }
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_history')
          .orderBy('timestamp');
      final snapshot = await ref.get();
      if (!mounted) return;
      setState(() {
        _messages = snapshot.docs.map((doc) => Message.fromJson(doc.data())).toList();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Firestore error in _loadChatHistory: $e');
    }
  }

  Future<void> _saveMessageToFirestore(Message message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_history');
      await ref.add(message.toJson());
    } catch (e) {
      print('Firestore error in _saveMessageToFirestore: $e');
    }
  }

  Future<void> _clearChatHistory() async {
    setState(() {
      _messages = [];
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_history');
      final snapshot = await ref.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final userMsg = Message(content: message, type: MessageType.user);
    if (!mounted) return;
    setState(() {
      _messages.add(userMsg);
      _messages.add(Message(content: 'AI is typing...', type: MessageType.loading));
      _isLoading = true;
      _messageController.clear();
    });
    await _saveMessageToFirestore(userMsg);
    _scrollToBottom();

    try {
      final response = await _gptService.getResponse(message);
      if (!mounted) return;
      setState(() {
        _messages.removeLast(); // Remove loading message
        final aiMsg = Message(
          content: response['message'],
          type: MessageType.assistant,
          scheduleData: response['scheduleData'],
        );
        _messages.add(aiMsg);
        _isLoading = false;
      });
      await _saveMessageToFirestore(_messages.last);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast(); // Remove loading message
        final errMsg = Message(content: 'Error: ${e.toString()}', type: MessageType.error);
        _messages.add(errMsg);
        _isLoading = false;
      });
      await _saveMessageToFirestore(_messages.last);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get response: ${e.toString()}')),
      );
    }
    _scrollToBottom();
  }

  // 判断是否为旅游行程
  bool _isTravelSchedule(ScheduleData? data) {
    if (data == null) return false;
    final title = data.title.toLowerCase();
    final notes = (data.notes ?? '').toLowerCase();
    return title.contains('travel') || title.contains('trip') || title.contains('tour') ||
           notes.contains('travel') || notes.contains('trip') || notes.contains('tour') ||
           title.contains('行程') || notes.contains('行程') || title.contains('景点') || notes.contains('景点');
  }

  // 判断是否为旅游行程（支持纯文本 message.content）
  bool _isTravelScheduleText(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('travel') || lower.contains('trip') || lower.contains('tour') ||
           lower.contains('行程') || lower.contains('一日游') || lower.contains('景点');
  }

  // 自动提取更自然的行程标题
  String extractTripTitle(String userInput) {
    final regex = RegExp(r'plan\s+(.+?\s+trip)(?:\s+for\s+me)?', caseSensitive: false);
    final match = regex.firstMatch(userInput);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }
    // 兜底：去掉plan/for me等常见词
    return userInput
        .replaceAll(RegExp(r'plan\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*for\s+me', caseSensitive: false), '')
        .trim();
  }

  void _addSchedule(ScheduleData scheduleData, {String? category, String? messageText, String? userInput, bool hideDueDate = false, bool isTravel = false}) {
    final now = DateTime.now();
    final dateTime = (scheduleData.datetime == null || scheduleData.datetime.isBefore(DateTime(2000)))
        ? now
        : scheduleData.datetime;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
          (kIsWeb || (!Platform.isAndroid && !Platform.isIOS))
            ? PhoneFrame(
                child: EditTaskPage(
                  initialTitle: userInput ?? scheduleData.title,
                  initialDateTime: dateTime,
                  initialNotes: messageText ?? '',
                  initialCategory: category,
                  hideDueDate: hideDueDate,
                  isTravel: isTravel,
                ),
              )
            : EditTaskPage(
                initialTitle: userInput ?? scheduleData.title,
                initialDateTime: dateTime,
                initialNotes: messageText ?? '',
                initialCategory: category,
                hideDueDate: hideDueDate,
                isTravel: isTravel,
              ),
      ),
    );
  }

  // 过滤 message 内容中的 JSON 代码块，只保留纯文本部分
  String filterJsonFromMessage(String text) {
    final jsonStart = text.indexOf('{');
    if (jsonStart != -1) {
      return text.substring(0, jsonStart).trim();
    }
    return text;
  }

  Widget _buildMessage(Message message) {
    Color bubbleColor;
    CrossAxisAlignment alignment;
    Color textColor = Colors.white;

    switch (message.type) {
      case MessageType.user:
        bubbleColor = Theme.of(context).primaryColor;
        alignment = CrossAxisAlignment.end;
        break;
      case MessageType.assistant:
        bubbleColor = Colors.grey[300]!;
        alignment = CrossAxisAlignment.start;
        textColor = Colors.black;
        break;
      case MessageType.loading:
        bubbleColor = Colors.grey[300]!;
        alignment = CrossAxisAlignment.start;
        textColor = Colors.black;
        break;
      case MessageType.error:
        bubbleColor = Colors.red[300]!;
        alignment = CrossAxisAlignment.center;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: alignment == CrossAxisAlignment.end
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (message.type == MessageType.assistant)
                CircleAvatar(
                  backgroundColor: Colors.grey[400],
                  child: const Icon(Icons.android, color: Colors.white),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: message.type == MessageType.loading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              message.content,
                              style: TextStyle(color: textColor),
                            ),
                          ],
                        )
                      : Text(
                          filterJsonFromMessage(message.content.replaceAll('\\n', '\n')),
                          style: TextStyle(color: textColor),
                        ),
                ),
              ),
              if (message.type == MessageType.user)
                const SizedBox(width: 8),
              if (message.type == MessageType.user)
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
            ],
          ),
          if (message.type == MessageType.assistant && message.scheduleData != null && !_isTravelSchedule(message.scheduleData))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _addSchedule(message.scheduleData!, messageText: ''),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Create Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          if (message.type == MessageType.assistant && message.scheduleData != null && _isTravelSchedule(message.scheduleData))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  final lastUserInput = _messages.lastWhereOrNull((m) => m.type == MessageType.user)?.content;
                  final taskName = lastUserInput != null ? extractTripTitle(lastUserInput) : message.scheduleData!.title;
                  _addSchedule(
                    message.scheduleData!,
                    category: 'Travel',
                    messageText: filterJsonFromMessage(message.content),
                    userInput: taskName,
                    hideDueDate: true,
                    isTravel: true,
                  );
                },
                icon: const Icon(Icons.flight_takeoff, color: Colors.white),
                label: const Text('Create Travel Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          if (message.type == MessageType.assistant && message.scheduleData == null && _isTravelScheduleText(message.content))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  final lastUserInput = _messages.lastWhereOrNull((m) => m.type == MessageType.user)?.content;
                  final taskName = lastUserInput != null ? extractTripTitle(lastUserInput) : 'Travel Plan';
                  _addSchedule(
                    ScheduleData(title: taskName, datetime: DateTime.now(), notes: filterJsonFromMessage(message.content)),
                    category: 'Travel',
                    messageText: filterJsonFromMessage(message.content),
                    userInput: taskName,
                    hideDueDate: true,
                    isTravel: true,
                  );
                },
                icon: const Icon(Icons.flight_takeoff, color: Colors.white),
                label: const Text('Create Travel Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Assistant', style: TextStyle(color: Theme.of(context).primaryColor)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Clear Chat History',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat History'),
                  content: const Text('Are you sure you want to delete all chat history?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _clearChatHistory();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
} 