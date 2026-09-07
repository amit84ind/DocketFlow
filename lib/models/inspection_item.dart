class InspectionItem {
  final int? id;
  final String title;
  final String date;
  final String location;
  final String rawSnippet;
  final int timestamp;
  final int isCompleted;

  InspectionItem({
    this.id,
    required this.title,
    required this.date,
    required this.location,
    required this.rawSnippet,
    required this.timestamp,
    this.isCompleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'location': location,
      'rawSnippet': rawSnippet,
      'timestamp': timestamp,
      'isCompleted': isCompleted,
    };
  }

  factory InspectionItem.fromMap(Map<String, dynamic> map) {
    return InspectionItem(
      id: map['id'],
      title: map['title'],
      date: map['date'],
      location: map['location'],
      rawSnippet: map['rawSnippet'],
      timestamp: map['timestamp'],
      isCompleted: map['isCompleted'] ?? 0,
    );
  }
}
