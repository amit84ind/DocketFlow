import '../models/inspection_item.dart';

class ParserService {
  static InspectionItem parsePayload(
    String title,
    String body,
    int postTime, {
    String source = 'Outlook',
  }) {
    final combined = '$title\n$body';

    // 1. Extraction of Inspection Date
    final dateRegex = RegExp(
      r'(?:date|inspection date|scheduled|schedule date|on|visit date)\s*[:\-#]?\s*([0-9A-Za-z/.\s-]{4,20})|(\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\b)|(\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*\d{0,4}\b)|(\b(?:today|tomorrow|next monday|next tuesday|next wednesday|next thursday|next friday)\b)',
      caseSensitive: false,
    );
    final dateMatch = dateRegex.firstMatch(combined);
    String extractedDate = "Date Mentioned In Mail";
    if (dateMatch != null) {
      extractedDate = (dateMatch.group(1) ?? dateMatch.group(2) ?? dateMatch.group(3) ?? dateMatch.group(4) ?? "Date Mentioned In Mail").trim();
    }

    // 2. Extraction of Place of Inspection / Location
    final locRegex = RegExp(
      r'(?:place|location|site|venue|premises|facility|plant|plot|factory|building|address|yard)\s*[:\-#]?\s*([A-Za-z0-9\-,\.\s]{3,35})',
      caseSensitive: false,
    );
    final locMatch = locRegex.firstMatch(combined);
    String extractedLoc = "General Site / Premises";
    if (locMatch != null && locMatch.group(1) != null) {
      extractedLoc = locMatch.group(1)!.trim();
    }

    // 3. Extraction of Vendor / Supplier Name
    final vendorRegex = RegExp(
      r'(?:vendor|supplier|mfg|manufacturer|contractor|agency|seller|provider)\s*[:\-#]?\s*([A-Za-z0-9&\-,\.\s]{2,30})',
      caseSensitive: false,
    );
    final vendorMatch = vendorRegex.firstMatch(combined);
    String extractedVendor = "Not Specified";
    if (vendorMatch != null && vendorMatch.group(1) != null) {
      extractedVendor = vendorMatch.group(1)!.trim();
    }

    // 4. Extraction of Client Name
    final clientRegex = RegExp(
      r'(?:client|customer|project owner|issued by|purchaser|buyer|authority|company)\s*[:\-#]?\s*([A-Za-z0-9&\-,\.\s]{2,30})',
      caseSensitive: false,
    );
    final clientMatch = clientRegex.firstMatch(combined);
    String extractedClient = "Not Specified";
    if (clientMatch != null && clientMatch.group(1) != null) {
      extractedClient = clientMatch.group(1)!.trim();
    }

    // 5. Extraction of Item Details
    final itemRegex = RegExp(
      r'(?:item|equipment|material|product|description|component|scope|goods|docket|type)\s*[:\-#]?\s*([A-Za-z0-9\-,\.\s]{3,45})',
      caseSensitive: false,
    );
    final itemMatch = itemRegex.firstMatch(combined);
    String extractedItems = "General Inspection Item";
    if (itemMatch != null && itemMatch.group(1) != null) {
      extractedItems = itemMatch.group(1)!.trim();
    }

    // 6. Extraction of Attachments
    final attachRegex = RegExp(
      r'([A-Za-z0-9\-_,\.\s]+\.(?:pdf|xlsx|xls|docx|doc|jpg|png|dwg|zip))|(?:attach|attachment|file|enclosed|report)\s*[:\-#]?\s*([A-Za-z0-9\-_,\.\s]+)',
      caseSensitive: false,
    );
    final attachMatches = attachRegex.allMatches(combined);
    List<String> foundAttachments = [];
    for (final match in attachMatches) {
      final file = (match.group(1) ?? match.group(2) ?? "").trim();
      if (file.isNotEmpty && !foundAttachments.contains(file)) {
        foundAttachments.add(file);
      }
    }
    String extractedAttachments = foundAttachments.isNotEmpty
        ? foundAttachments.join(', ')
        : "No attachments detected";

    // Priority detection
    final highPriorityTriggers = ['urgent', 'critical', 'high priority', 'asap', 'immediate', 'severe', 'mandatory'];
    final isHigh = highPriorityTriggers.any((p) => combined.toLowerCase().contains(p));

    return InspectionItem(
      title: title.trim().isNotEmpty ? title.trim() : "Outlook Docket Inspection",
      date: extractedDate,
      location: extractedLoc,
      vendorName: extractedVendor,
      clientName: extractedClient,
      itemDetails: extractedItems,
      attachments: extractedAttachments,
      rawSnippet: body.length > 300 ? '${body.substring(0, 297)}...' : body,
      timestamp: postTime > 0 ? postTime : DateTime.now().millisecondsSinceEpoch,
      source: source,
      priority: isHigh ? 'High' : 'Normal',
    );
  }
}
