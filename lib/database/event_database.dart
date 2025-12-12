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
      version: 2,
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
        $columnReminderMinutes INTEGER
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
      );
    });
  }

  // 关闭数据库
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
