import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/user_score.dart';
import '../models/achievement.dart';
import '../models/ai_explanation.dart';

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
      version: 4,
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

    // 创建AI解答表
    await db.execute('''
      CREATE TABLE ai_explanations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_record_id INTEGER NOT NULL,
        explanation TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      )
    ''');

    // 创建AI解答表索引
    await db.execute('''
      CREATE INDEX idx_ai_explanations_quiz_record_id ON ai_explanations (quiz_record_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_ai_explanations_created_at ON ai_explanations (created_at)
    ''');

    // 创建答题记录表
    await db.execute('''
      CREATE TABLE quiz_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        question_text TEXT NOT NULL,
        question_type TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        user_answer TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        score INTEGER NOT NULL DEFAULT 0,
        answered_at INTEGER NOT NULL,
        time_spent INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 创建答题记录表索引
    await db.execute('''
      CREATE INDEX idx_quiz_records_question_id ON quiz_records (question_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_quiz_records_answered_at ON quiz_records (answered_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_quiz_records_is_correct ON quiz_records (is_correct)
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

    if (oldVersion < 3) {
      // 创建AI解答表
      await db.execute('''
        CREATE TABLE ai_explanations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quiz_record_id INTEGER NOT NULL,
          explanation TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // 创建AI解答表索引
      await db.execute('''
        CREATE INDEX idx_ai_explanations_quiz_record_id ON ai_explanations (quiz_record_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_ai_explanations_created_at ON ai_explanations (created_at)
      ''');
    }

    if (oldVersion < 4) {
      // 创建答题记录表
      await db.execute('''
        CREATE TABLE quiz_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          question_id INTEGER NOT NULL,
          question_text TEXT NOT NULL,
          question_type TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          user_answer TEXT NOT NULL,
          correct_answer TEXT NOT NULL,
          is_correct INTEGER NOT NULL DEFAULT 0,
          score INTEGER NOT NULL DEFAULT 0,
          answered_at INTEGER NOT NULL,
          time_spent INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // 创建答题记录表索引
      await db.execute('''
        CREATE INDEX idx_quiz_records_question_id ON quiz_records (question_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_quiz_records_answered_at ON quiz_records (answered_at)
      ''');

      await db.execute('''
        CREATE INDEX idx_quiz_records_is_correct ON quiz_records (is_correct)
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

  // AI解答相关操作
  Future<int> insertAIExplanation(AIExplanation explanation) async {
    final db = await database;
    return await db.insert('ai_explanations', explanation.toMap());
  }

  Future<AIExplanation?> getAIExplanationByQuizRecordId(int quizRecordId) async {
    final db = await database;
    final maps = await db.query(
      'ai_explanations',
      where: 'quiz_record_id = ?',
      whereArgs: [quizRecordId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return AIExplanation.fromMap(maps.first);
    }
    return null;
  }

  Future<List<AIExplanation>> getAIExplanationsByQuizRecordId(int quizRecordId) async {
    final db = await database;
    final maps = await db.query(
      'ai_explanations',
      where: 'quiz_record_id = ?',
      whereArgs: [quizRecordId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AIExplanation.fromMap(map)).toList();
  }

  Future<int> updateAIExplanation(AIExplanation explanation) async {
    final db = await database;
    return await db.update(
      'ai_explanations',
      explanation.toMap(),
      where: 'id = ?',
      whereArgs: [explanation.id],
    );
  }

  Future<int> deleteAIExplanation(int id) async {
    final db = await database;
    return await db.delete('ai_explanations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAIExplanationByQuizRecordId(int quizRecordId) async {
    final db = await database;
    return await db.delete(
      'ai_explanations',
      where: 'quiz_record_id = ?',
      whereArgs: [quizRecordId],
    );
  }

  Future<List<AIExplanation>> getAllAIExplanations() async {
    final db = await database;
    final maps = await db.query(
      'ai_explanations',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AIExplanation.fromMap(map)).toList();
  }

  Future<List<AIExplanation>> getRecentAIExplanations({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'ai_explanations',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => AIExplanation.fromMap(map)).toList();
  }

  Future<List<AIExplanation>> getAIExplanationsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'ai_explanations',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => AIExplanation.fromMap(map)).toList();
  }

  Future<int> getAIExplanationCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ai_explanations');
    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }

  // 答题记录相关操作
  Future<int> insertQuizRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('quiz_records', record);
  }

  Future<List<Map<String, dynamic>>> getQuizRecords({
    int? limit,
    int? offset,
    String? orderBy,
    bool? descending,
  }) async {
    final db = await database;

    String orderClause = 'answered_at DESC'; // 默认按答题时间倒序
    if (orderBy != null) {
      orderClause = '$orderBy ${descending == false ? 'ASC' : 'DESC'}';
    }

    final maps = await db.query(
      'quiz_records',
      orderBy: orderClause,
      limit: limit,
      offset: offset,
    );
    return maps;
  }

  Future<Map<String, dynamic>?> getQuizRecordById(int id) async {
    final db = await database;
    final maps = await db.query(
      'quiz_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getQuizRecordsByQuestionId(int questionId) async {
    final db = await database;
    final maps = await db.query(
      'quiz_records',
      where: 'question_id = ?',
      whereArgs: [questionId],
      orderBy: 'answered_at DESC',
    );
    return maps;
  }

  Future<List<Map<String, dynamic>>> getQuizRecordsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? orderBy,
    bool? descending,
  }) async {
    final db = await database;

    String orderClause = 'answered_at DESC';
    if (orderBy != null) {
      orderClause = '$orderBy ${descending == false ? 'ASC' : 'DESC'}';
    }

    final maps = await db.query(
      'quiz_records',
      where: 'answered_at BETWEEN ? AND ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: orderClause,
    );
    return maps;
  }

  Future<int> updateQuizRecord(int id, Map<String, dynamic> record) async {
    final db = await database;
    return await db.update(
      'quiz_records',
      record,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteQuizRecord(int id) async {
    final db = await database;
    return await db.delete('quiz_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getQuizRecordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM quiz_records');
    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }

  Future<Map<String, dynamic>> getQuizStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_questions,
        SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) as correct_questions,
        SUM(score) as total_score,
        SUM(time_spent) as total_time_spent,
        MAX(answered_at) as last_quiz_date
      FROM quiz_records
    ''');

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'totalQuestions': row['total_questions'] ?? 0,
        'correctQuestions': row['correct_questions'] ?? 0,
        'totalScore': row['total_score'] ?? 0,
        'totalTimeSpent': row['total_time_spent'] ?? 0,
        'lastQuizDate': row['last_quiz_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['last_quiz_date'] as int)
            : DateTime.now(),
      };
    }

    return {
      'totalQuestions': 0,
      'correctQuestions': 0,
      'totalScore': 0,
      'totalTimeSpent': 0,
      'lastQuizDate': DateTime.now(),
    };
  }

  Future<Map<String, int>> getDifficultyStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        difficulty,
        COUNT(*) as count
      FROM quiz_records
      GROUP BY difficulty
      ORDER BY count DESC
    ''');

    Map<String, int> stats = {};
    for (var row in result) {
      stats[row['difficulty'] as String] = row['count'] as int;
    }

    return stats;
  }
}
