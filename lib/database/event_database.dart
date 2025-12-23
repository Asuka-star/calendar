import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event.dart';

class EventDatabase {
  static const String tableName = 'events';
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnStartTime = 'start_time';
  static const String columnEndTime = 'end_time';
  static const String columnDescription = 'description';
  static const String columnReminderMinutes = 'reminder_minutes';
  static const String columnCreated = 'created';
  static const String columnLastModified = 'last_modified';
  static const String columnSequence = 'sequence';

  static Database? _database;

  // 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 初始化数据库
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'calendar.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  // 创建数据表
  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT NOT NULL,
        $columnStartTime TEXT NOT NULL,
        $columnEndTime TEXT NOT NULL,
        $columnDescription TEXT,
        $columnReminderMinutes INTEGER,
        $columnCreated TEXT NOT NULL,
        $columnLastModified TEXT NOT NULL,
        $columnSequence INTEGER DEFAULT 0
      )
    ''');
  }

  // 数据库升级
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加 reminder_minutes 字段
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnReminderMinutes INTEGER',
      );
    }
    if (oldVersion < 3) {
      // 添加 RFC 5545 标准字段
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnCreated TEXT DEFAULT "${DateTime.now().toIso8601String()}"',
      );
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnLastModified TEXT DEFAULT "${DateTime.now().toIso8601String()}"',
      );
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnSequence INTEGER DEFAULT 0',
      );
    }
  }

  // 插入或更新事件
  Future<int> insertOrUpdateEvent(Event event) async {
    final db = await database;
    return await db.insert(tableName, {
      columnId: event.id,
      columnTitle: event.title,
      columnStartTime: event.startTime.toIso8601String(),
      columnEndTime: event.endTime.toIso8601String(),
      columnDescription: event.description,
      columnReminderMinutes: event.reminderMinutes,
      columnCreated: event.created.toIso8601String(),
      columnLastModified: event.lastModified.toIso8601String(),
      columnSequence: event.sequence,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 删除事件
  Future<int> deleteEvent(String id) async {
    final db = await database;
    return await db.delete(tableName, where: '$columnId = ?', whereArgs: [id]);
  }

  // 获取所有事件
  Future<List<Event>> getAllEvents() async {
    final db = await database;
    final maps = await db.query(tableName);
    return List.generate(maps.length, (i) {
      return Event(
        id: maps[i][columnId] as String,
        title: maps[i][columnTitle] as String,
        startTime: DateTime.parse(maps[i][columnStartTime] as String),
        endTime: DateTime.parse(maps[i][columnEndTime] as String),
        description: maps[i][columnDescription] as String?,
        reminderMinutes: maps[i][columnReminderMinutes] as int?,
        created: maps[i][columnCreated] != null
            ? DateTime.parse(maps[i][columnCreated] as String)
            : DateTime.now(),
        lastModified: maps[i][columnLastModified] != null
            ? DateTime.parse(maps[i][columnLastModified] as String)
            : DateTime.now(),
        sequence: maps[i][columnSequence] as int? ?? 0,
      );
    });
  }

  // 获取指定日期的事件
  Future<List<Event>> getEventsByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final maps = await db.query(
      tableName,
      where: '$columnStartTime >= ? AND $columnStartTime <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: columnStartTime,
    );

    return List.generate(maps.length, (i) {
      return Event(
        id: maps[i][columnId] as String,
        title: maps[i][columnTitle] as String,
        startTime: DateTime.parse(maps[i][columnStartTime] as String),
        endTime: DateTime.parse(maps[i][columnEndTime] as String),
        description: maps[i][columnDescription] as String?,
        reminderMinutes: maps[i][columnReminderMinutes] as int?,
        created: maps[i][columnCreated] != null
            ? DateTime.parse(maps[i][columnCreated] as String)
            : DateTime.now(),
        lastModified: maps[i][columnLastModified] != null
            ? DateTime.parse(maps[i][columnLastModified] as String)
            : DateTime.now(),
        sequence: maps[i][columnSequence] as int? ?? 0,
      );
    });
  }

  // 关闭数据库
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
