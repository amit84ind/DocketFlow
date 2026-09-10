class InspectionItem {
  final int? id;
  final String title;
  final String date;
  final String location;
  final String vendorName;
  final String clientName;
  final String itemDetails;
  final String attachments;
  final String rawSnippet;
  final int timestamp;
  final int isCompleted;
  final String source;
  final String priority;

  InspectionItem({
    this.id,
    required this.title,
    required this.date,
    required this.location,
    this.vendorName = 'Not Specified',
    this.clientName = 'Not Specified',
    this.itemDetails = 'General Inspection',
    this.attachments = 'No attachments',
    required this.rawSnippet,
    required this.timestamp,
    this.isCompleted = 0,
    this.source = 'Outlook',
    this.priority = 'Normal',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'location': location,
      'vendorName': vendorName,
      'clientName': clientName,
      'itemDetails': itemDetails,
      'attachments': attachments,
      'rawSnippet': rawSnippet,
      'timestamp': timestamp,
      'isCompleted': isCompleted,
      'source': source,
      'priority': priority,
    };
  }

  factory InspectionItem.fromMap(Map<String, dynamic> map) {
    return InspectionItem(
      id: map['id'],
      title: map['title'] ?? 'Inspection Docket',
      date: map['date'] ?? 'Date Mentioned In Mail',
      location: map['location'] ?? 'General Site / Premises',
      vendorName: map['vendorName'] ?? 'Not Specified',
      clientName: map['clientName'] ?? 'Not Specified',
      itemDetails: map['itemDetails'] ?? 'General Inspection',
      attachments: map['attachments'] ?? 'No attachments',
      rawSnippet: map['rawSnippet'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      isCompleted: map['isCompleted'] ?? 0,
      source: map['source'] ?? 'Outlook',
      priority: map['priority'] ?? 'Normal',
    );
  }
}
