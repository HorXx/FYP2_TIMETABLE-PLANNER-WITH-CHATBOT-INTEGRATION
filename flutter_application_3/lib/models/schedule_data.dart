class ScheduleData {
  final String title;
  final DateTime datetime;
  final String? notes;

  ScheduleData({
    required this.title,
    required this.datetime,
    this.notes,
  });

  factory ScheduleData.fromJson(Map<String, dynamic> json) {
    return ScheduleData(
      title: json['title'] as String,
      datetime: DateTime.parse(json['datetime'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'datetime': datetime.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
} 