import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'service_logs.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            description TEXT,
            date TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insertLog(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('logs', row);
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    Database db = await database;
    return await db.query('logs', orderBy: 'id DESC');
  }

  static Future<int> deleteLog(int id) async {
    Database db = await database;
    return await db.delete('logs', where: 'id = ?', whereArgs: [id]);
  }
}
