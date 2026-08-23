import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  // Database ကို ချိတ်ဆက်ရန် (Initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Database Table များ ဖန်တီးရန်
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // 1. Data ထည့်သွင်းခြင်း (Insert)
  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('items', row);
  }

  // 2. Data အားလုံးကို ဖတ်ရှုခြင်း (Read All)
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    final db = await instance.database;
    return await db.query('items');
  }

  // 3. Data ကို ပြင်ဆင်မွမ်းမံခြင်း (Update)
  Future<int> updateItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'items',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 4. Data ကို ဖျက်ဆီးခြင်း (Delete)
  Future<int> deleteItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Database ကို ပိတ်ရန်
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
