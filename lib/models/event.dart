class Event {
  final String id;
  final String title;
  final DateTime date;
  final String? description;

  Event({
    required this.id,
    required this.title,
    required this.date,
    this.description,
  });

  Event copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? description,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String?,
    );
  }
}
