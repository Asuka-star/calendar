class Event {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final int? reminderMinutes; // 提醒时间：开始前几分钟
  final DateTime created; // 创建时间
  final DateTime lastModified; // 最后修改时间
  final int sequence; // 版本序号，每次修改递增

  Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.reminderMinutes,
    DateTime? created,
    DateTime? lastModified,
    this.sequence = 0,
  }) : created = created ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now();

  // 获取事件的日期（不包含时间）
  DateTime get date => DateTime(startTime.year, startTime.month, startTime.day);

  Event copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    int? reminderMinutes,
    DateTime? created,
    DateTime? lastModified,
    int? sequence,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      created: created ?? this.created,
      lastModified: lastModified ?? DateTime.now(), // 修改时更新时间
      sequence: sequence ?? (this.sequence + 1), // 修改时递增版本号
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
      'created': created.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'sequence': sequence,
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
      created: json['created'] != null
          ? DateTime.parse(json['created'] as String)
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
      sequence: json['sequence'] as int? ?? 0,
    );
  }
}
