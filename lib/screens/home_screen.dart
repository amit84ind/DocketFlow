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
  StreamSubscription? _notificationSubscription;

  List<InspectionItem> _items = [];
  bool _autoCleanup = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndData();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _notificationSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) async {
      if (event is Map) {
        final title = (event['title'] as String?) ?? '';
        final text = (event['text'] as String?) ?? '';
        final timestamp = (event['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

        final item = ParserService.parsePayload(title, text, timestamp);
        await DBHelper.instance.insertInspection(item);
        _loadSettingsAndData();
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
      _items = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DocketFlow", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: Colors.amber),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          )
        ],
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text(
                "No inspections captured yet.\nIncoming Outlook/Gmail inspections will appear automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isCompleted == 1 ? Colors.green.shade100 : Colors.blue.shade100,
                      child: Icon(
                        item.isCompleted == 1 ? Icons.check : Icons.schedule,
                        color: item.isCompleted == 1 ? Colors.green : Colors.blue,
                      ),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("📅 ${item.date}  •  📍 ${item.location}"),
                        Text(item.rawSnippet, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Checkbox(
                      value: item.isCompleted == 1,
                      onChanged: (val) async {
                        await DBHelper.instance.toggleStatus(item.id!, val == true ? 1 : 0);
                        _loadSettingsAndData();
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
