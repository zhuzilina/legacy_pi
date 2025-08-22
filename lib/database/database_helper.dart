import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/user_score.dart';
import '../models/achievement.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  // 获取数据库实例
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'legacy_pi.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // 创建数据库表
  Future<void> _createDatabase(Database db, int version) async {
    // 创建用户表
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        avatar_path TEXT,
        nickname TEXT,
        bio TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 创建用户积分表
    await db.execute('''
      CREATE TABLE user_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        score INTEGER NOT NULL DEFAULT 0,
        description TEXT NOT NULL,
        earned_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 创建成就表
    await db.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        earned_at INTEGER NOT NULL,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 创建索引以提高查询性能
    await db.execute('''
      CREATE INDEX idx_user_scores_user_id ON user_scores (user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_user_scores_earned_at ON user_scores (earned_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_achievements_user_id ON achievements (user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_achievements_earned_at ON achievements (earned_at)
    ''');
  }

  // 数据库升级
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // 添加新字段到用户表
      await db.execute('ALTER TABLE users ADD COLUMN avatar_path TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN nickname TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN bio TEXT');

      // 创建成就表
      await db.execute('''
        CREATE TABLE achievements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          icon TEXT NOT NULL,
          earned_at INTEGER NOT NULL,
          is_unlocked INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      // 创建成就表索引
      await db.execute('''
        CREATE INDEX idx_achievements_user_id ON achievements (user_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_achievements_earned_at ON achievements (earned_at)
      ''');
    }
  }

  // 用户相关操作
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'created_at DESC');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // 积分相关操作
  Future<int> insertUserScore(UserScore userScore) async {
    final db = await database;
    return await db.insert('user_scores', userScore.toMap());
  }

  Future<List<UserScore>> getUserScores(int userId) async {
    final db = await database;
    final maps = await db.query(
      'user_scores',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'earned_at DESC',
    );
    return maps.map((map) => UserScore.fromMap(map)).toList();
  }

  Future<int> getTotalUserScore(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(score) as total FROM user_scores WHERE user_id = ?',
      [userId],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  Future<int> updateUserScore(UserScore userScore) async {
    final db = await database;
    return await db.update(
      'user_scores',
      userScore.toMap(),
      where: 'id = ?',
      whereArgs: [userScore.id],
    );
  }

  Future<int> deleteUserScore(int id) async {
    final db = await database;
    return await db.delete('user_scores', where: 'id = ?', whereArgs: [id]);
  }

  // 删除用户的所有积分记录
  Future<int> deleteAllUserScores(int userId) async {
    final db = await database;
    return await db.delete(
      'user_scores',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // 获取积分排行榜
  Future<List<Map<String, dynamic>>> getScoreLeaderboard({
    int limit = 10,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        u.id,
        u.username,
        u.email,
        SUM(us.score) as total_score
      FROM users u
      LEFT JOIN user_scores us ON u.id = us.user_id
      GROUP BY u.id, u.username, u.email
      ORDER BY total_score DESC
      LIMIT ?
    ''',
      [limit],
    );

    return result;
  }

  // 关闭数据库
  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // 删除数据库（用于测试）
  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'legacy_pi.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // 成就相关操作
  Future<int> insertAchievement(Achievement achievement) async {
    final db = await database;
    return await db.insert('achievements', achievement.toMap());
  }

  Future<List<Achievement>> getUserAchievements(int userId) async {
    final db = await database;
    final maps = await db.query(
      'achievements',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'earned_at DESC',
    );
    return maps.map((map) => Achievement.fromMap(map)).toList();
  }

  Future<int> getUnlockedAchievementsCount(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM achievements WHERE user_id = ? AND is_unlocked = 1',
      [userId],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }

  Future<int> updateAchievement(Achievement achievement) async {
    final db = await database;
    return await db.update(
      'achievements',
      achievement.toMap(),
      where: 'id = ?',
      whereArgs: [achievement.id],
    );
  }

  Future<int> deleteAchievement(int id) async {
    final db = await database;
    return await db.delete('achievements', where: 'id = ?', whereArgs: [id]);
  }

  // 删除用户的所有成就记录
  Future<int> deleteAllUserAchievements(int userId) async {
    final db = await database;
    return await db.delete(
      'achievements',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // 解锁成就
  Future<void> unlockAchievement(
    int userId,
    String name,
    String description,
    String icon,
  ) async {
    final db = await database;

    // 检查是否已经解锁
    final existing = await db.query(
      'achievements',
      where: 'user_id = ? AND name = ?',
      whereArgs: [userId, name],
    );

    if (existing.isEmpty) {
      await db.insert(
        'achievements',
        Achievement(
          userId: userId,
          name: name,
          description: description,
          icon: icon,
          earnedAt: DateTime.now(),
          isUnlocked: true,
        ).toMap(),
      );
    }
  }
}
