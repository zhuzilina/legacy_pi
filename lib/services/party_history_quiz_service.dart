import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// 党史题库API服务
class PartyHistoryQuizService {
  /// 获取指定分类下的题目ID列表
  static Future<Map<String, dynamic>?> getQuestionIdsByCategory({
    required String category,
  }) async {
    try {
      final baseUrl = await ApiConfig.knowledgeQuizBaseUrl;
      final url = '$baseUrl/questions/?category=$category';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          print('获取题目ID列表失败: ${data['error'] ?? '未知错误'}');
          return null;
        }
      } else {
        print('获取题目ID列表请求失败: ${response.statusCode}');
        print('响应内容: ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取题目ID列表异常: $e');
      return null;
    }
  }

  /// 根据题目ID获取题目详细信息
  static Future<Map<String, dynamic>?> getQuestionById({
    required int questionId,
  }) async {
    try {
      final baseUrl = await ApiConfig.knowledgeQuizBaseUrl;
      final url = '$baseUrl/questions/$questionId/';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          print('获取题目详情失败: ${data['error'] ?? '未知错误'}');
          return null;
        }
      } else {
        print('获取题目详情请求失败: ${response.statusCode}');
        print('响应内容: ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取题目详情异常: $e');
      return null;
    }
  }

  /// 获取党史分类的所有题目
  static Future<Map<String, dynamic>?> getPartyHistoryQuestions() async {
    return await getQuestionIdsByCategory(category: 'party_history');
  }

  /// 获取理论分类的所有题目
  static Future<Map<String, dynamic>?> getTheoryQuestions() async {
    return await getQuestionIdsByCategory(category: 'theory');
  }
}

/// 题目数据模型
class QuizQuestion {
  final int id;
  final String questionText;
  final String questionType;
  final String questionTypeDisplay;
  final String difficulty;
  final String difficultyDisplay;
  final String category;
  final String categoryDisplay;
  final List<String> tags;
  final String explanation;
  final List<Map<String, dynamic>> options;
  final List<Map<String, dynamic>> correctOptions;
  final String correctAnswerText;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.questionTypeDisplay,
    required this.difficulty,
    required this.difficultyDisplay,
    required this.category,
    required this.categoryDisplay,
    required this.tags,
    required this.explanation,
    required this.options,
    required this.correctOptions,
    required this.correctAnswerText,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? 0,
      questionText: json['question_text'] ?? '',
      questionType: json['question_type'] ?? '',
      questionTypeDisplay: json['question_type_display'] ?? '',
      difficulty: json['difficulty'] ?? '',
      difficultyDisplay: json['difficulty_display'] ?? '',
      category: json['category'] ?? '',
      categoryDisplay: json['category_display'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      explanation: json['explanation'] ?? '',
      options: List<Map<String, dynamic>>.from(json['options'] ?? []),
      correctOptions: List<Map<String, dynamic>>.from(json['correct_options'] ?? []),
      correctAnswerText: json['correct_answer_text'] ?? '',
    );
  }

  /// 判断是否为单选题
  bool get isSingleChoice => questionType == 'choice_single';

  /// 判断是否为多选题
  bool get isMultipleChoice => questionType == 'choice_multiple';

  /// 判断是否为填空题
  bool get isFillInBlank => questionType == 'fill';

  /// 获取正确答案的文本
  List<String> get correctAnswers {
    return correctOptions.map((option) => option['text'] as String).toList();
  }

  /// 转换为JSON格式（用于AI解答组件）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'question_type': questionType,
      'question_type_display': questionTypeDisplay,
      'difficulty': difficulty,
      'difficulty_display': difficultyDisplay,
      'category': category,
      'category_display': categoryDisplay,
      'tags': tags,
      'explanation': explanation,
      'options': options,
      'correct_options': correctOptions,
      'correct_answer_text': correctAnswerText,
    };
  }
}

/// 题目ID信息模型
class QuestionIdInfo {
  final int id;
  final String questionType;
  final String difficulty;

  QuestionIdInfo({
    required this.id,
    required this.questionType,
    required this.difficulty,
  });

  factory QuestionIdInfo.fromJson(Map<String, dynamic> json) {
    return QuestionIdInfo(
      id: json['id'] ?? 0,
      questionType: json['question_type'] ?? '',
      difficulty: json['difficulty'] ?? '',
    );
  }
}

/// 题目分类响应模型
class CategoryQuestionsResponse {
  final String category;
  final String categoryDisplay;
  final int totalCount;
  final List<QuestionIdInfo> questionIds;

  CategoryQuestionsResponse({
    required this.category,
    required this.categoryDisplay,
    required this.totalCount,
    required this.questionIds,
  });

  factory CategoryQuestionsResponse.fromJson(Map<String, dynamic> json) {
    final questionIdsList = (json['question_ids'] as List?)
            ?.map((item) => QuestionIdInfo.fromJson(item))
            .toList() ??
        [];

    return CategoryQuestionsResponse(
      category: json['category'] ?? '',
      categoryDisplay: json['category_display'] ?? '',
      totalCount: json['total_count'] ?? 0,
      questionIds: questionIdsList,
    );
  }
}