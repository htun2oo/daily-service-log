import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('service_logs.db');
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
          CREATE TABLE service_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            customer_name TEXT NOT NULL,
            service_type TEXT NOT NULL,
            amount REAL NOT NULL,
            remarks TEXT,
            title TEXT,
            description TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('service_logs', row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    final db = await instance.database;
    return await db.query('service_logs', orderBy: 'id DESC');
  }

  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('service_logs', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete('service_logs', where: 'id = ?', whereArgs: [id]);
  }
}
