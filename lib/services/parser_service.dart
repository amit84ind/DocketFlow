import '../models/inspection_item.dart';

class ParserService {
  static InspectionItem parsePayload(String title, String body, int postTime) {
    final combined = '$title $body';
    
    // Date matching regex (DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, or DD Mon)
    final dateRegex = RegExp(
      r'(\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b)|(\b\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*(\s+\d{2,4})?\b)',
      caseSensitive: false,
    );
    final dateMatch = dateRegex.firstMatch(combined);
    final extractedDate = dateMatch != null ? dateMatch.group(0)! : "Date Mentioned In Mail";

    // Location/Site regex
    final locRegex = RegExp(r'(site|plot|flat|building|tower|premises|plant)\s*[:\-#]?\s*([A-Za-z0-9\-\s]{2,15})', caseSensitive: false);
    final locMatch = locRegex.firstMatch(combined);
    final extractedLoc = locMatch != null ? locMatch.group(0)! : "General Premises";

    return InspectionItem(
      title: title.isNotEmpty ? title : "Upcoming Inspection",
      date: extractedDate,
      location: extractedLoc,
      rawSnippet: body.length > 80 ? '${body.substring(0, 77)}...' : body,
      timestamp: postTime > 0 ? postTime : DateTime.now().millisecondsSinceEpoch,
    );
  }
}
