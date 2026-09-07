import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/inspection_item.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('docketflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inspections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            date TEXT,
            location TEXT,
            rawSnippet TEXT,
            timestamp INTEGER,
            isCompleted INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertInspection(InspectionItem item) async {
    final db = await instance.database;
    return await db.insert('inspections', item.toMap());
  }

  Future<List<InspectionItem>> getInspections() async {
    final db = await instance.database;
    final maps = await db.query('inspections', orderBy: 'timestamp DESC');
    return maps.map((e) => InspectionItem.fromMap(e)).toList();
  }

  Future<int> toggleStatus(int id, int status) async {
    final db = await instance.database;
    return await db.update(
      'inspections',
      {'isCompleted': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 7-Day Automatic Purge Logic
  Future<int> purgeOldDockets(int daysThreshold) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: daysThreshold)).millisecondsSinceEpoch;
    return await db.delete('inspections', where: 'timestamp < ?', whereArgs: [cutoff]);
  }
}
