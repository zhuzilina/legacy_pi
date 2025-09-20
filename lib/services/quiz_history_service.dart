import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/ai_explanation.dart';

/// 答题记录数据模型
class QuizRecord {
  final int? id; // 数据库ID（新增）
  final int questionId;
  final String questionText;
  final String questionType;
  final String difficulty;
  final List<String> userAnswer;
  final List<String> correctAnswer;
  final bool isCorrect;
  final int score;
  final DateTime answeredAt;
  final int timeSpent; // 答题耗时（秒）

  QuizRecord({
    this.id,
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.difficulty,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.score,
    required this.answeredAt,
    required this.timeSpent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionId': questionId,
      'questionText': questionText,
      'questionType': questionType,
      'difficulty': difficulty,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect ? 1 : 0,
      'score': score,
      'answeredAt': answeredAt.millisecondsSinceEpoch,
      'timeSpent': timeSpent,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question_id': questionId,
      'question_text': questionText,
      'question_type': questionType,
      'difficulty': difficulty,
      'user_answer': json.encode(userAnswer),
      'correct_answer': json.encode(correctAnswer),
      'is_correct': isCorrect ? 1 : 0,
      'score': score,
      'answered_at': answeredAt.millisecondsSinceEpoch,
      'time_spent': timeSpent,
    };
  }

  factory QuizRecord.fromJson(Map<String, dynamic> json) {
    return QuizRecord(
      id: json['id'],
      questionId: json['questionId'] ?? 0,
      questionText: json['questionText'] ?? '',
      questionType: json['questionType'] ?? '',
      difficulty: json['difficulty'] ?? '',
      userAnswer: List<String>.from(json['userAnswer'] ?? []),
      correctAnswer: List<String>.from(json['correctAnswer'] ?? []),
      isCorrect: json['isCorrect'] == 1 || json['isCorrect'] == true,
      score: json['score'] ?? 0,
      answeredAt: json['answeredAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['answeredAt'])
          : DateTime.now(),
      timeSpent: json['timeSpent'] ?? 0,
    );
  }

  factory QuizRecord.fromMap(Map<String, dynamic> map) {
    return QuizRecord(
      id: map['id'],
      questionId: map['question_id'] ?? 0,
      questionText: map['question_text'] ?? '',
      questionType: map['question_type'] ?? '',
      difficulty: map['difficulty'] ?? '',
      userAnswer: map['user_answer'] != null
          ? (map['user_answer'] as String).split(',').where((s) => s.isNotEmpty).toList()
          : [],
      correctAnswer: map['correct_answer'] != null
          ? (map['correct_answer'] as String).split(',').where((s) => s.isNotEmpty).toList()
          : [],
      isCorrect: map['is_correct'] == 1,
      score: map['score'] ?? 0,
      answeredAt: map['answered_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['answered_at'])
          : DateTime.now(),
      timeSpent: map['time_spent'] ?? 0,
    );
  }
}

/// 答题统计信息
class QuizStats {
  final int totalQuestions;
  final int correctQuestions;
  final int totalScore;
  final int totalTimeSpent;
  final DateTime lastQuizDate;
  final Map<String, int> difficultyStats; // 难度统计

  QuizStats({
    required this.totalQuestions,
    required this.correctQuestions,
    required this.totalScore,
    required this.totalTimeSpent,
    required this.lastQuizDate,
    required this.difficultyStats,
  });

  double get accuracyRate => totalQuestions > 0 ? (correctQuestions / totalQuestions) * 100 : 0;
  double get averageTimePerQuestion => totalQuestions > 0 ? totalTimeSpent / totalQuestions : 0;

  Map<String, dynamic> toJson() {
    return {
      'totalQuestions': totalQuestions,
      'correctQuestions': correctQuestions,
      'totalScore': totalScore,
      'totalTimeSpent': totalTimeSpent,
      'lastQuizDate': lastQuizDate.millisecondsSinceEpoch,
      'difficultyStats': difficultyStats,
    };
  }

  factory QuizStats.fromJson(Map<String, dynamic> json) {
    return QuizStats(
      totalQuestions: json['totalQuestions'] ?? 0,
      correctQuestions: json['correctQuestions'] ?? 0,
      totalScore: json['totalScore'] ?? 0,
      totalTimeSpent: json['totalTimeSpent'] ?? 0,
      lastQuizDate: json['lastQuizDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastQuizDate'])
          : DateTime.now(),
      difficultyStats: Map<String, int>.from(json['difficultyStats'] ?? {}),
    );
  }
}

/// 答题记录服务
class QuizHistoryService {
  static const String _quizHistoryKey = 'quiz_history';
  static const String _quizStatsKey = 'quiz_stats';

  /// 保存答题记录
  static Future<void> saveQuizRecord(QuizRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getQuizHistory();

      // 添加新记录
      history.add(record);

      // 只保留最近100条记录
      if (history.length > 100) {
        history.removeRange(0, history.length - 100);
      }

      // 保存到缓存
      final historyJson = history.map((r) => r.toJson()).toList();
      await prefs.setString(_quizHistoryKey, json.encode(historyJson));

      // 更新统计信息
      await _updateQuizStats(record);

      print('答题记录已保存: 题目${record.questionId}, ${record.isCorrect ? "正确" : "错误"}');
    } catch (e) {
      print('保存答题记录失败: $e');
    }
  }

  /// 获取答题历史
  static Future<List<QuizRecord>> getQuizHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_quizHistoryKey);

      if (historyJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(historyJson);
      return decoded.map((item) => QuizRecord.fromJson(item)).toList();
    } catch (e) {
      print('获取答题历史失败: $e');
      return [];
    }
  }

  /// 获取答题统计
  static Future<QuizStats> getQuizStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_quizStatsKey);

      if (statsJson == null) {
        return QuizStats(
          totalQuestions: 0,
          correctQuestions: 0,
          totalScore: 0,
          totalTimeSpent: 0,
          lastQuizDate: DateTime.now(),
          difficultyStats: {},
        );
      }

      final decoded = json.decode(statsJson);
      return QuizStats.fromJson(decoded);
    } catch (e) {
      print('获取答题统计失败: $e');
      return QuizStats(
        totalQuestions: 0,
        correctQuestions: 0,
        totalScore: 0,
        totalTimeSpent: 0,
        lastQuizDate: DateTime.now(),
        difficultyStats: {},
      );
    }
  }

  /// 更新统计信息
  static Future<void> _updateQuizStats(QuizRecord record) async {
    try {
      final stats = await getQuizStats();

      final updatedStats = QuizStats(
        totalQuestions: stats.totalQuestions + 1,
        correctQuestions: stats.correctQuestions + (record.isCorrect ? 1 : 0),
        totalScore: stats.totalScore + record.score,
        totalTimeSpent: stats.totalTimeSpent + record.timeSpent,
        lastQuizDate: DateTime.now(),
        difficultyStats: Map.from(stats.difficultyStats),
      );

      // 更新难度统计
      updatedStats.difficultyStats[record.difficulty] =
          (updatedStats.difficultyStats[record.difficulty] ?? 0) + 1;

      // 保存统计信息
      final statsJson = json.encode(updatedStats.toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quizStatsKey, statsJson);

    } catch (e) {
      print('更新答题统计失败: $e');
    }
  }

  /// 清空答题历史
  static Future<void> clearQuizHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_quizHistoryKey);
      await prefs.remove(_quizStatsKey);
      print('答题历史已清空');
    } catch (e) {
      print('清空答题历史失败: $e');
    }
  }

  /// 获取今日答题记录
  static Future<List<QuizRecord>> getTodayQuizHistory() async {
    final history = await getQuizHistory();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return history.where((record) =>
      record.answeredAt.isAfter(todayStart)
    ).toList();
  }

  /// 获取本周答题记录
  static Future<List<QuizRecord>> getThisWeekQuizHistory() async {
    final history = await getQuizHistory();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final adjustedWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

    return history.where((record) =>
      record.answeredAt.isAfter(adjustedWeekStart)
    ).toList();
  }

  /// 获取本月答题记录
  static Future<List<QuizRecord>> getThisMonthQuizHistory() async {
    final history = await getQuizHistory();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return history.where((record) =>
      record.answeredAt.isAfter(monthStart)
    ).toList();
  }
}