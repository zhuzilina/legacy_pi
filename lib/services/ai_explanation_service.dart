import '../database/database_helper.dart';
import '../models/ai_explanation.dart';

/// AI解答服务
class AIExplanationService {
  static final AIExplanationService _instance = AIExplanationService._internal();
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  AIExplanationService._internal();

  factory AIExplanationService() => _instance;

  /// 保存AI解答内容
  static Future<int?> saveAIExplanation({
    required int quizRecordId,
    required String explanation,
  }) async {
    try {
      final aiExplanation = AIExplanation(
        quizRecordId: quizRecordId,
        explanation: explanation,
        createdAt: DateTime.now(),
      );

      final id = await _databaseHelper.insertAIExplanation(aiExplanation);
      print('AI解答已保存: quizRecordId=$quizRecordId, id=$id');
      return id;
    } catch (e) {
      print('保存AI解答失败: $e');
      return null;
    }
  }

  /// 获取AI解答内容
  static Future<AIExplanation?> getAIExplanation(int quizRecordId) async {
    try {
      return await _databaseHelper.getAIExplanationByQuizRecordId(quizRecordId);
    } catch (e) {
      print('获取AI解答失败: $e');
      return null;
    }
  }

  /// 获取指定答题记录的所有AI解答
  static Future<List<AIExplanation>> getAIExplanations(int quizRecordId) async {
    try {
      return await _databaseHelper.getAIExplanationsByQuizRecordId(quizRecordId);
    } catch (e) {
      print('获取AI解答列表失败: $e');
      return [];
    }
  }

  /// 更新AI解答内容
  static Future<bool> updateAIExplanation(AIExplanation explanation) async {
    try {
      final updated = explanation.copyWith(updatedAt: DateTime.now());
      final result = await _databaseHelper.updateAIExplanation(updated);
      return result > 0;
    } catch (e) {
      print('更新AI解答失败: $e');
      return false;
    }
  }

  /// 删除AI解答
  static Future<bool> deleteAIExplanation(int id) async {
    try {
      final result = await _databaseHelper.deleteAIExplanation(id);
      return result > 0;
    } catch (e) {
      print('删除AI解答失败: $e');
      return false;
    }
  }

  /// 删除指定答题记录的所有AI解答
  static Future<bool> deleteAIExplanationByQuizRecordId(int quizRecordId) async {
    try {
      final result = await _databaseHelper.deleteAIExplanationByQuizRecordId(quizRecordId);
      return result > 0;
    } catch (e) {
      print('删除AI解答失败: $e');
      return false;
    }
  }

  /// 获取所有AI解答
  static Future<List<AIExplanation>> getAllAIExplanations() async {
    try {
      return await _databaseHelper.getAllAIExplanations();
    } catch (e) {
      print('获取所有AI解答失败: $e');
      return [];
    }
  }

  /// 获取最近的AI解答
  static Future<List<AIExplanation>> getRecentAIExplanations({int limit = 50}) async {
    try {
      return await _databaseHelper.getRecentAIExplanations(limit: limit);
    } catch (e) {
      print('获取最近AI解答失败: $e');
      return [];
    }
  }

  /// 获取日期范围内的AI解答
  static Future<List<AIExplanation>> getAIExplanationsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _databaseHelper.getAIExplanationsByDateRange(startDate, endDate);
    } catch (e) {
      print('获取日期范围内AI解答失败: $e');
      return [];
    }
  }

  /// 获取AI解答总数
  static Future<int> getAIExplanationCount() async {
    try {
      return await _databaseHelper.getAIExplanationCount();
    } catch (e) {
      print('获取AI解答总数失败: $e');
      return 0;
    }
  }

  /// 获取带AI解答的答题记录列表
  static Future<List<Map<String, dynamic>>> getQuizRecordsWithAIExplanation({
    int? limit,
    int? offset,
  }) async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 查询包含AI解答的答题记录
      final maps = await db.rawQuery('''
        SELECT
          qr.id,
          qr.question_id,
          qr.question_text,
          qr.question_type,
          qr.difficulty,
          qr.user_answer,
          qr.correct_answer,
          qr.is_correct,
          qr.score,
          qr.answered_at,
          qr.time_spent,
          ae.explanation,
          ae.created_at as ai_explanation_created_at
        FROM quiz_records qr
        LEFT JOIN ai_explanations ae ON qr.id = ae.quiz_record_id
        WHERE ae.id IS NOT NULL
        ORDER BY qr.answered_at DESC
        LIMIT ? OFFSET ?
      ''', [limit ?? 50, offset ?? 0]);

      return maps;
    } catch (e) {
      print('获取带AI解答的答题记录失败: $e');
      return [];
    }
  }

  /// 清空所有AI解答数据
  static Future<bool> clearAllAIExplanations() async {
    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      await db.delete('ai_explanations');
      print('所有AI解答数据已清空');
      return true;
    } catch (e) {
      print('清空AI解答数据失败: $e');
      return false;
    }
  }
}