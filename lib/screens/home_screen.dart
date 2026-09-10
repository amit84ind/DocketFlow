import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inspection_item.dart';
import '../services/db_helper.dart';
import '../services/parser_service.dart';
import 'subscription_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _eventChannel = EventChannel('com.docketflow/notifications');
  static const _methodChannel = MethodChannel('com.docketflow/settings');
  StreamSubscription? _notificationSubscription;

  List<InspectionItem> _allItem = [];
  List<InspectionItem> _filteredItems = [];
  bool _autoCleanup = true;
  bool _isNotificationServiceActive = false;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSettingsAndData();
    _listenToNotifications();
    _checkNotificationPermissionStatus();
    _checkPendingSharedText();
  }

  Future<void> _checkPendingSharedText() async {
    try {
      final String? shared = await _methodChannel.invokeMethod('getPendingSharedText');
      if (shared != null && shared.trim().isNotEmpty) {
        final lines = shared.trim().split('\n');
        final title = lines.isNotEmpty ? lines.first : 'Outlook Shared Email';
        final body = lines.length > 1 ? lines.sublist(1).join('\n') : shared;

        final item = ParserService.parsePayload(
          title,
          body,
          DateTime.now().millisecondsSinceEpoch,
          source: 'Outlook',
        );

        await DBHelper.instance.insertInspection(item);
        _loadSettingsAndData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.share, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Imported '${item.title}' via Outlook Share!")),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _checkNotificationPermissionStatus() async {
    try {
      final bool active = await _methodChannel.invokeMethod('isNotificationServiceEnabled') ?? false;
      setState(() {
        _isNotificationServiceActive = active;
      });
    } catch (_) {
      setState(() {
        _isNotificationServiceActive = false;
      });
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      final res = await _methodChannel.invokeMethod('openNotificationSettings');
      if (res != true) {
        _showSmartEmailImportModal();
      } else {
        await Future.delayed(const Duration(seconds: 1));
        _checkNotificationPermissionStatus();
      }
    } catch (_) {
      _showSmartEmailImportModal();
    }
  }

  void _listenToNotifications() {
    _notificationSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) async {
      if (event is Map) {
        final title = (event['title'] as String?) ?? '';
        final text = (event['text'] as String?) ?? '';
        final timestamp = (event['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
        final source = (event['source'] as String?) ?? 'Outlook';

        final item = ParserService.parsePayload(title, text, timestamp, source: source);
        await DBHelper.instance.insertInspection(item);
        _loadSettingsAndData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.mark_email_unread, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text("New ${item.source} Inspection Docket Auto-Captured!")),
                ],
              ),
              backgroundColor: Colors.blueAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }, onError: (dynamic error) {
      debugPrint("Notification event error: $error");
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _loadSettingsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _autoCleanup = prefs.getBool('auto_cleanup') ?? true;

    if (_autoCleanup) {
      await DBHelper.instance.purgeOldDockets(7);
    }

    final data = await DBHelper.instance.getInspections();
    setState(() {
      _allItem = data;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<InspectionItem> temp = List.from(_allItem);

    if (_selectedFilter == 'Outlook') {
      temp = temp.where((i) => i.source.toLowerCase() == 'outlook').toList();
    } else if (_selectedFilter == 'High Priority') {
      temp = temp.where((i) => i.priority.toLowerCase() == 'high').toList();
    } else if (_selectedFilter == 'Pending') {
      temp = temp.where((i) => i.isCompleted == 0).toList();
    } else if (_selectedFilter == 'Completed') {
      temp = temp.where((i) => i.isCompleted == 1).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp = temp.where((i) {
        return i.title.toLowerCase().contains(q) ||
            i.location.toLowerCase().contains(q) ||
            i.vendorName.toLowerCase().contains(q) ||
            i.clientName.toLowerCase().contains(q) ||
            i.itemDetails.toLowerCase().contains(q) ||
            i.rawSnippet.toLowerCase().contains(q);
      }).toList();
    }

    _filteredItems = temp;
  }

  void _showSmartEmailImportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _SmartEmailImportSheet(
          onSave: (item) async {
            await DBHelper.instance.insertInspection(item);
            _loadSettingsAndData();
            if (mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Inspection Docket Successfully Retracted & Added!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _showInspectionDetailsModal(InspectionItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                item.source == 'Outlook' ? Icons.email : Icons.mail_outline,
                color: item.source == 'Outlook' ? Colors.blue : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(Icons.calendar_today, "Inspection Date", item.date, Colors.blue),
                _detailRow(Icons.location_on, "Place of Inspection", item.location, Colors.redAccent),
                _detailRow(Icons.store, "Vendor / Supplier", item.vendorName, Colors.orange),
                _detailRow(Icons.business, "Client Name", item.clientName, Colors.purple),
                _detailRow(Icons.inventory_2, "Item Details", item.itemDetails, Colors.teal),
                _detailRow(Icons.attach_file, "Attachments", item.attachments, Colors.indigo),
                const Divider(height: 24),
                const Text("Raw Email Content Snippet:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.rawSnippet,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DocketFlow", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded, color: Colors.blueAccent),
            tooltip: 'Test & Trial',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSmartEmailImportModal,
        icon: const Icon(Icons.auto_awesome),
        label: const Text("Smart Import Mail"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Banner for Outlook Sync Status
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isNotificationServiceActive
                    ? [Colors.blue.shade800, Colors.blue.shade500]
                    : [Colors.amber.shade800, Colors.orange.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isNotificationServiceActive ? Icons.sync : Icons.sync_problem,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNotificationServiceActive
                            ? "Outlook Auto-Sync Active"
                            : "Enable Outlook Mail Reader",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _isNotificationServiceActive
                            ? "Automatically retracting inspection dockets from Outlook emails"
                            : "Tap to grant notification listener access for Outlook",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isNotificationServiceActive
                      ? _showSmartEmailImportModal
                      : _openNotificationSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    _isNotificationServiceActive ? "Import Mail" : "Enable",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: "Search date, site, vendor, client...",
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Filter Choice Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: ['All', 'Outlook', 'High Priority', 'Pending', 'Completed'].map((filter) {
                final selected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    selectedColor: Colors.blueAccent.withOpacity(0.2),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedFilter = filter;
                          _applyFilters();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 16),

          // Docket Cards List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          "No inspection dockets found.",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Incoming Outlook emails will auto-appear,\nor use 'Smart Import Mail' to paste email details.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _showSmartEmailImportModal,
                          icon: const Icon(Icons.add),
                          label: const Text("Smart Import Outlook Mail"),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return Dismissible(
                        key: Key('item_${item.id}_${item.timestamp}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          if (item.id != null) {
                            await DBHelper.instance.deleteInspection(item.id!);
                            _loadSettingsAndData();
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: item.priority == 'High'
                                  ? Colors.redAccent.withOpacity(0.5)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showInspectionDetailsModal(item),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Card Top Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item.source == 'Outlook'
                                              ? Colors.blue.shade100
                                              : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.source == 'Outlook' ? Icons.email : Icons.mail,
                                              size: 12,
                                              color: item.source == 'Outlook' ? Colors.blue.shade900 : Colors.red.shade900,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.source,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: item.source == 'Outlook' ? Colors.blue.shade900 : Colors.red.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (item.priority == 'High')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "URGENT",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      Checkbox(
                                        value: item.isCompleted == 1,
                                        onChanged: (val) async {
                                          await DBHelper.instance.toggleStatus(item.id!, val == true ? 1 : 0);
                                          _loadSettingsAndData();
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // Title
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      decoration: item.isCompleted == 1
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Details List
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _infoRow(Icons.calendar_today, "Date", item.date, Colors.blue),
                                      _infoRow(Icons.location_on, "Place", item.location, Colors.redAccent),
                                      if (item.vendorName != 'Not Specified')
                                        _infoRow(Icons.store, "Vendor", item.vendorName, Colors.orange),
                                      if (item.clientName != 'Not Specified')
                                        _infoRow(Icons.business, "Client", item.clientName, Colors.purple),
                                      if (item.itemDetails != 'General Inspection')
                                        _infoRow(Icons.inventory_2, "Item", item.itemDetails, Colors.teal),
                                      if (item.attachments != 'No attachments detected')
                                        _infoRow(Icons.attach_file, "Attachments", item.attachments, Colors.indigo),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modal Sheet for Smart Importing / Retracting Outlook Email
class _SmartEmailImportSheet extends StatefulWidget {
  final Function(InspectionItem) onSave;

  const _SmartEmailImportSheet({required this.onSave});

  @override
  State<_SmartEmailImportSheet> createState() => _SmartEmailImportSheetState();
}

class _SmartEmailImportSheetState extends State<_SmartEmailImportSheet> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  InspectionItem? _previewItem;

  @override
  void initState() {
    super.initState();
    _subjectController.addListener(_updatePreview);
    _bodyController.addListener(_updatePreview);
  }

  void _updatePreview() {
    final title = _subjectController.text;
    final body = _bodyController.text;
    if (title.isNotEmpty || body.isNotEmpty) {
      setState(() {
        _previewItem = ParserService.parsePayload(
          title,
          body,
          DateTime.now().millisecondsSinceEpoch,
          source: 'Outlook',
        );
      });
    } else {
      setState(() {
        _previewItem = null;
      });
    }
  }

  void _loadSample(String sampleTitle, String sampleBody) {
    _subjectController.text = sampleTitle;
    _bodyController.text = sampleBody;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text(
                  "Retract Outlook Email Info",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              "Paste Outlook email text below or tap a sample to see smart extraction in action.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Quick Samples
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                    label: const Text("Sample 1: Site Audit"),
                    onPressed: () => _loadSample(
                      "Inspection Schedule - Sector 62 Plant",
                      "Dear Team,\nInspection Date: 18/11/2024\nPlace: Plot 42, Sector 62 Industrial Yard\nVendor: L&T Construction\nClient: Apex Infrastructure\nItem: High Voltage Transformer Unit\nAttachments: Safety_Specs.pdf, Layout.dwg\nPlease complete compliance review.",
                    ),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.warning_amber, size: 14, color: Colors.redAccent),
                    label: const Text("Sample 2: URGENT Equipment Visit"),
                    onPressed: () => _loadSample(
                      "URGENT: Safety Visit & Quality Check",
                      "Site Visit Date: Tomorrow\nLocation: Facility Building B, Plant 3\nSupplier: Siemens Engineering\nCustomer: Metro Rail Corp\nEquipment: Hydraulic Lift Pump\nAttached: Audit_Report_2024.pdf",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: "Email Subject",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _bodyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Email Body / Details (Paste from Outlook)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 14),

            // Live Smart Preview
            if (_previewItem != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, size: 18, color: Colors.blueAccent),
                        SizedBox(width: 6),
                        Text(
                          "Smart Extracted Data:",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("📅 Date: ${_previewItem!.date}"),
                    Text("📍 Place: ${_previewItem!.location}"),
                    Text("🏭 Vendor: ${_previewItem!.vendorName}"),
                    Text("🏢 Client: ${_previewItem!.clientName}"),
                    Text("📦 Item: ${_previewItem!.itemDetails}"),
                    Text("📎 Attachments: ${_previewItem!.attachments}"),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  final title = _subjectController.text.trim();
                  final body = _bodyController.text.trim();
                  if (title.isEmpty && body.isEmpty) return;

                  final item = ParserService.parsePayload(
                    title,
                    body,
                    DateTime.now().millisecondsSinceEpoch,
                    source: 'Outlook',
                  );
                  widget.onSave(item);
                },
                icon: const Icon(Icons.check, color: Colors.white),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                label: const Text(
                  "Retract & Save to DocketFlow",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
