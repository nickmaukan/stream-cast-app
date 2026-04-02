import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/video_stream.dart';

/// Database service for history and favorites
class DatabaseService {
  static Database? _database;
  static const String _dbName = 'maukan_cast.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        thumbnailUrl TEXT,
        description TEXT,
        sourceType TEXT DEFAULT 'direct',
        addedAt TEXT NOT NULL,
        lastPlayedAt TEXT,
        playCount INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0,
        deviceId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT NOT NULL UNIQUE,
        favicon TEXT,
        addedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_videos_addedAt ON videos(addedAt DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_videos_isFavorite ON videos(isFavorite)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations
  }

  // Video operations
  Future<int> insertVideo(VideoStream video) async {
    final db = await database;
    return db.insert(
      'videos',
      video.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VideoStream>> getHistory({int limit = 50, int offset = 0}) async {
    final db = await database;
    final maps = await db.query(
      'videos',
      where: 'isFavorite = ?',
      whereArgs: [0],
      orderBy: 'addedAt DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => VideoStream.fromMap(m)).toList();
  }

  Future<List<VideoStream>> getFavorites({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'videos',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'addedAt DESC',
      limit: limit,
    );
    return maps.map((m) => VideoStream.fromMap(m)).toList();
  }

  Future<VideoStream?> getVideoByUrl(String url) async {
    final db = await database;
    final maps = await db.query(
      'videos',
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return VideoStream.fromMap(maps.first);
  }

  Future<void> updateVideo(VideoStream video) async {
    final db = await database;
    await db.update(
      'videos',
      video.toMap(),
      where: 'id = ?',
      whereArgs: [video.id],
    );
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final db = await database;
    await db.update(
      'videos',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteVideo(int id) async {
    final db = await database;
    await db.delete('videos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('videos', where: 'isFavorite = ?', whereArgs: [0]);
  }

  Future<void> incrementPlayCount(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE videos SET playCount = playCount + 1, lastPlayedAt = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  // Bookmark operations
  Future<int> insertBookmark(String title, String url, {String? favicon}) async {
    final db = await database;
    return db.insert(
      'bookmarks',
      {
        'title': title,
        'url': url,
        'favicon': favicon,
        'addedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final db = await database;
    return db.query('bookmarks', orderBy: 'addedAt DESC');
  }

  Future<void> deleteBookmark(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // Search
  Future<List<VideoStream>> searchVideos(String query) async {
    final db = await database;
    final maps = await db.query(
      'videos',
      where: 'title LIKE ? OR url LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'addedAt DESC',
      limit: 20,
    );
    return maps.map((m) => VideoStream.fromMap(m)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
