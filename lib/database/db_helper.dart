import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/tile_model.dart';

class DesignDbHelper {
  static final DesignDbHelper instance = DesignDbHelper._init();
  static Database? _database;

  DesignDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(
        'design_tiles_v2.db'); // поменяли имя файла базы, чтобы обновилась структура
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
          CREATE TABLE tiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            widthCm REAL,
            heightCm REAL,
            pricePerSquareMeter REAL,
            imagePath TEXT,
            type TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertTile(DesignTile tile) async {
    final db = await instance.database;
    return await db.insert('tiles', tile.toMap());
  }

  Future<List<DesignTile>> getAllTiles() async {
    final db = await instance.database;
    final result = await db.query('tiles');
    return result.map((json) => DesignTile.fromMap(json)).toList();
  }

  Future<int> deleteTile(int id) async {
    final db = await instance.database;
    return await db.delete('tiles', where: 'id = ?', whereArgs: [id]);
  }

  // Метод для обновления существующего кафеля
  Future<int> updateTile(DesignTile tile) async {
    final db = await instance.database;
    return await db.update(
      'tiles',
      tile.toMap(),
      where: 'id = ?',
      whereArgs: [tile.id],
    );
  }
}
