import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_result.dart'; // Nous créerons ce modèle juste après

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scolarai.db');
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

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
    CREATE TABLE scan_results (
      id $idType,
      imagePath $textType,
      ocrResults $textType,
      confidences $textType,
      cropImages $textType,
      scannedAt $textType,
      note $textType,
      nom $textType,
      prenom $textType,
      matiere $textType
    )
    ''');
  }

  Future<ScanResult> create(ScanResult result) async {
    final db = await instance.database;
    final id = await db.insert('scan_results', result.toJson());
    return result.copy(id: id);
  }

  Future<ScanResult> readResult(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'scan_results',
      columns: ScanResult.fields,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ScanResult.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<ScanResult>> readAllResults() async {
    final db = await instance.database;
    const orderBy = 'scannedAt DESC';
    final result = await db.query('scan_results', orderBy: orderBy);

    return result.map((json) => ScanResult.fromJson(json)).toList();
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'scan_results',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
