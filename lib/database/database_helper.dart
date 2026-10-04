import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance =
      DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbDirectory = await getDatabasesPath();

    final dbPath = p.join(
      dbDirectory,
      'expense_tracker.db',
    );

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant TEXT NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            note TEXT,
            imagePath TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertExpense(
    Map<String, dynamic> expense,
  ) async {
    final db = await database;

    return db.insert(
      'expenses',
      expense,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;

    return db.query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    );
  }

  Future<int> updateExpense(
    int id,
    Map<String, dynamic> expense,
  ) async {
    final db = await database;

    return db.update(
      'expenses',
      expense,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;

    return db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}