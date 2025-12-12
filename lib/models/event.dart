class Event {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final int? reminderMinutes; // 提醒时间：开始前几分钟

  Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.reminderMinutes,
  });

  // 获取事件的日期（不包含时间）
  DateTime get date => DateTime(startTime.year, startTime.month, startTime.day);

  Event copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    int? reminderMinutes,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'description': description,
      'reminderMinutes': reminderMinutes,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      description: json['description'] as String?,
      reminderMinutes: json['reminderMinutes'] as int?,
    );
  }
}
