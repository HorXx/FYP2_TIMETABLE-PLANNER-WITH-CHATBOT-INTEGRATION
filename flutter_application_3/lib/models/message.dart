import 'package:flutter/material.dart';
import 'schedule_data.dart';

enum MessageType {
  user,
  assistant,
  loading,
  error,
}

class Message {
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final ScheduleData? scheduleData;

  Message({
    required this.content,
    required this.type,
    DateTime? timestamp,
    this.scheduleData,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'content': content,
    'type': type.index,
    'timestamp': timestamp.toIso8601String(),
    'scheduleData': scheduleData?.toJson(),
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    content: json['content'],
    type: MessageType.values[json['type']],
    timestamp: DateTime.parse(json['timestamp']),
    scheduleData: json['scheduleData'] != null ? ScheduleData.fromJson(json['scheduleData']) : null,
  );
} 