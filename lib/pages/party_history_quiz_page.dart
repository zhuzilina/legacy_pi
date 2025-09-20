import 'dart:math';
import 'package:flutter/material.dart';
import '../services/party_history_quiz_service.dart';
import '../database/database_helper.dart';
import '../models/user_score.dart';
import '../services/global_state.dart';
import '../models/user.dart';
import '../services/quiz_history_service.dart';
import '../services/ai_explanation_service.dart';
import 'quiz_history_page.dart';
import '../widgets/ai_explanation_widget.dart';

class PartyHistoryQuizPage extends StatefulWidget {
  final bool fromHistory;

  const PartyHistoryQuizPage({
    super.key,
    this.fromHistory = false,
  });

  @override
  State<PartyHistoryQuizPage> createState() => _PartyHistoryQuizPageState();
}

class _PartyHistoryQuizPageState extends State<PartyHistoryQuizPage> {
  bool _isLoading = true;
  String _error = '';
  CategoryQuestionsResponse? _categoryData;
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<String> _userAnswers = [];
  bool _isCorrect = false;
  int _score = 0;
  User? _currentUser;
  Set<int> _answeredQuestionIds = {}; // 已答题目的ID集合
  static const int _batchSize = 10; // 每批题目数量
  int _batchCorrectCount = 0; // 当前组答对题目数
  int _batchTotalScore = 0; // 当前组总积分
  DateTime? _questionStartTime; // 题目开始时间
  bool _allQuestionsCompleted = false; // 所有题目是否已完成
  int? _currentQuizRecordId; // 当前答题记录的数据库ID

  @override
  void initState() {
    super.initState();
    _resetQuizState(); // 重置答题状态
    _loadCurrentUser();
    _loadAnsweredQuestions(); // 先加载已答题目
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleNavigationArguments(); // 处理导航参数
  }

  // 处理从历史记录导航过来的参数
  void _handleNavigationArguments() {
    if (widget.fromHistory) {
      // 从ModalRoute获取传递的参数
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        // 这里可以处理从历史记录传递过来的参数
        // 例如跳转到特定题目，显示之前的答案等
        print('从历史记录导航，参数: $args');

        // TODO: 实现跳转到特定题目的逻辑
        // 1. 加载所有题目
        // 2. 找到对应的题目ID
        // 3. 设置当前索引
        // 4. 显示之前的答案和解释
      }
    }
  }

  // 加载当前用户
  Future<void> _loadCurrentUser() async {
    try {
      final globalState = GlobalState();
      _currentUser = globalState.currentUser;

      if (_currentUser == null) {
        await _loadUserFromDatabase();
      }
    } catch (e) {
      print('加载用户失败: $e');
    }
  }

  // 重置答题状态
  void _resetQuizState() {
    setState(() {
      _questions = [];
      _currentIndex = 0;
      _showAnswer = false;
      _userAnswers = [];
      _isCorrect = false;
      _score = 0;
      _batchCorrectCount = 0;
      _batchTotalScore = 0;
      _questionStartTime = null;
      _allQuestionsCompleted = false;
    });
  }

  // 加载已答题目记录
  Future<void> _loadAnsweredQuestions() async {
    try {
      // 从数据库加载已答题目记录，而不是 SharedPreferences
      final dbHelper = DatabaseHelper();
      final quizRecords = await dbHelper.getQuizRecords();
      setState(() {
        _answeredQuestionIds = quizRecords.map((record) => record['question_id'] as int).toSet();
      });
      print('已从数据库加载 ${_answeredQuestionIds.length} 条已答题目记录');

      // 加载题目
      _loadQuestions();
    } catch (e) {
      print('从数据库加载已答题目失败: $e');
      // 如果加载失败，尝试从 SharedPreferences 加载作为备选
      try {
        final history = await QuizHistoryService.getQuizHistory();
        setState(() {
          _answeredQuestionIds = history.map((record) => record.questionId).toSet();
        });
        print('已从 SharedPreferences 加载 ${_answeredQuestionIds.length} 条已答题目记录');
      } catch (e2) {
        print('从 SharedPreferences 加载也失败: $e2');
      }
      // 无论哪种方式都加载题目
      _loadQuestions();
    }
  }

  // 从数据库加载用户
  Future<void> _loadUserFromDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> users = await dbHelper.database.then((db) {
        return db.query('users', limit: 1);
      });

      if (users.isNotEmpty) {
        final userData = users.first;
        setState(() {
          _currentUser = User(
            id: userData['id'],
            username: userData['username'] ?? userData['nickname'] ?? '用户',
            email: userData['email'] ?? 'user@example.com',
            avatarPath: userData['avatar_path'],
            nickname: userData['nickname'] ?? userData['username'] ?? '用户',
            createdAt: userData['created_at'] != null
                ? DateTime.parse(userData['created_at'])
                : DateTime.now(),
            updatedAt: userData['updated_at'] != null
                ? DateTime.parse(userData['updated_at'])
                : DateTime.now(),
          );
        });
      }
    } catch (e) {
      print('从数据库加载用户失败: $e');
    }
  }

  // 加载题目列表
  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 获取党史题目的ID列表
      final categoryData = await PartyHistoryQuizService.getPartyHistoryQuestions();
      if (categoryData != null) {
        _categoryData = CategoryQuestionsResponse.fromJson(categoryData);

        // 加载第一组题目
        await _loadNextBatch();
      } else {
        setState(() {
          _error = '加载题目失败，请稍后重试';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载题目失败: $e';
        _isLoading = false;
      });
    }
  }

  // 加载下一组题目
  Future<void> _loadNextBatch() async {
    if (_categoryData == null) return;

    setState(() {
      _isLoading = true;
      _questions = [];
      _currentIndex = 0;
      _showAnswer = false;
      _userAnswers = [];
      _isCorrect = false;
      _score = 0;
      _batchCorrectCount = 0;
      _batchTotalScore = 0;
      _questionStartTime = null;
    });

    try {
      // 获取未答题目的ID列表
      final allQuestionIds = _categoryData!.questionIds;
      final unansweredQuestionIds = allQuestionIds
          .where((q) => !_answeredQuestionIds.contains(q.id))
          .toList();

      if (unansweredQuestionIds.isEmpty) {
        // 所有题目都已答完，显示完成状态
        setState(() {
          _isLoading = false;
          _questions = [];
          _allQuestionsCompleted = true;
        });
        return;
      }

      // 获取当前批次的题目（最多10道）
      final batchSize = _batchSize;

      // 每次进入页面都重新计算可用的题目，并随机打乱
      final shuffledQuestions = List<QuestionIdInfo>.from(unansweredQuestionIds);
      shuffledQuestions.shuffle();

      // 确保每次都能获取到不同的一组题目
      final actualBatchSize = min(batchSize, shuffledQuestions.length);
      final currentBatchQuestionIds = shuffledQuestions.sublist(0, actualBatchSize);

      // 如果没有足够的未答题目，从已答题目中随机选择一些来补充
      if (currentBatchQuestionIds.length < batchSize) {
        final answeredQuestionIds = allQuestionIds
            .where((q) => _answeredQuestionIds.contains(q.id))
            .toList();
        answeredQuestionIds.shuffle();

        final neededCount = batchSize - currentBatchQuestionIds.length;
        final supplementaryQuestions = answeredQuestionIds.sublist(
          0,
          min(neededCount, answeredQuestionIds.length),
        );
        currentBatchQuestionIds.addAll(supplementaryQuestions);
      }

      List<QuizQuestion> questions = [];
      for (var questionInfo in currentBatchQuestionIds) {
        final questionData = await PartyHistoryQuizService.getQuestionById(
          questionId: questionInfo.id,
        );
        if (questionData != null) {
          questions.add(QuizQuestion.fromJson(questionData));
        }
      }

      setState(() {
        _questions = questions;
        _isLoading = false;
        _questionStartTime = DateTime.now(); // 设置第一道题的开始时间
      });
    } catch (e) {
      setState(() {
        _error = '加载题目失败: $e';
        _isLoading = false;
      });
    }
  }

  // 处理用户答题
  void _handleAnswer(List<String> answers) {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final currentQuestion = _questions[_currentIndex];
    final correctAnswers = currentQuestion.correctAnswers;

    // 判断答案是否正确
    bool isCorrect = false;
    if (currentQuestion.isSingleChoice) {
      isCorrect = answers.length == 1 && correctAnswers.contains(answers[0]);
    } else if (currentQuestion.isMultipleChoice) {
      isCorrect = answers.length == correctAnswers.length &&
                  answers.every((answer) => correctAnswers.contains(answer));
    } else if (currentQuestion.isFillInBlank) {
      isCorrect = answers.length == 1 &&
                  answers[0].trim().toLowerCase() ==
                  correctAnswers[0].trim().toLowerCase();
    }

    setState(() {
      _userAnswers = answers;
      _showAnswer = true;
      _isCorrect = isCorrect;
      _score = isCorrect ? 10 : 0; // 每题10分，答错0分
    });

    // 记录已答题目ID和统计
    _answeredQuestionIds.add(currentQuestion.id);
    if (isCorrect) {
      _batchCorrectCount++;
      _batchTotalScore += 10; // 每答对一题获得10积分
    }

    // 保存积分到数据库
    _saveScoreToDatabase();

    // 保存答题记录
    _saveQuizRecord();
  }

  // 保存答题记录
  Future<void> _saveQuizRecord() async {
    try {
      if (_questions.isEmpty || _currentIndex >= _questions.length) return;

      final currentQuestion = _questions[_currentIndex];
      final timeSpent = _questionStartTime != null ? DateTime.now().difference(_questionStartTime!).inSeconds : 0;

      final dbHelper = DatabaseHelper();

      // 创建 QuizRecord 对象
      final quizRecord = QuizRecord(
        questionId: currentQuestion.id,
        questionText: currentQuestion.questionText,
        questionType: currentQuestion.questionTypeDisplay,
        difficulty: currentQuestion.difficultyDisplay,
        userAnswer: _userAnswers,
        correctAnswer: currentQuestion.correctAnswers,
        isCorrect: _isCorrect,
        score: _score,
        answeredAt: DateTime.now(),
        timeSpent: timeSpent,
      );

      final recordId = await dbHelper.insertQuizRecord(quizRecord.toMap());
      setState(() {
        _currentQuizRecordId = recordId;
      });

      print('答题记录已保存到数据库: 题目${currentQuestion.id}, ID: $recordId, 用时$timeSpent秒');
      print('保存的题目内容: ${currentQuestion.questionText.substring(0, 30)}...');
      print('用户答案: ${_userAnswers.join(',')}');
      print('正确答案: ${currentQuestion.correctAnswers.join(',')}');
    } catch (e) {
      print('保存答题记录到数据库失败: $e');
    }
  }

  // 保存积分到数据库
  Future<void> _saveScoreToDatabase() async {
    try {
      if (_currentUser == null || _score <= 0) return;

      final dbHelper = DatabaseHelper();

      // 创建积分记录
      final userScore = UserScore(
        userId: _currentUser!.id!,
        score: _score,
        description: '党史题库答题正确获得积分 - 每题10分',
        earnedAt: DateTime.now(),
      );

      // 保存到数据库
      await dbHelper.insertUserScore(userScore);
      print('积分已保存到数据库: 用户${_currentUser!.id} 获得$_score分');
    } catch (e) {
      print('保存积分到数据库失败: $e');
    }
  }

  // 下一题
  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
        _userAnswers = [];
        _isCorrect = false;
        _score = 0;
        _questionStartTime = DateTime.now(); // 重置题目开始时间
      });
    } else {
      // 本组答题完成，显示完成页面
      _showCompletionDialog();
    }
  }

  // 重置当前题目答题状态（用于AI解答后的重试）
  void _resetCurrentQuestion() {
    setState(() {
      _showAnswer = false;
      _userAnswers = [];
      _isCorrect = false;
      _score = 0;
      _currentQuizRecordId = null; // 重置答题记录ID
    });
  }

  // 显示完成对话框
  void _showCompletionDialog() {
    final remainingCount = (_categoryData?.totalCount ?? 0) - _answeredQuestionIds.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              const Text(
                '本组答题完成',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // 积分展示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber[600],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '本组获得 $_batchTotalScore 积分',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '答对 $_batchCorrectCount 题，每题10分',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),

              // 按钮
              if (remainingCount > 0) ...[
                // 是否再来一组提示
                const Text(
                  '是否再来一组题目？',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // 按钮行
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.grey[700],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '返回',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _loadNextBatch();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '再来一组',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // 所有题目已完成
                const Text(
                  '恭喜您已完成所有党史题目！',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '返回',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('党史题库'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuizHistoryPage()),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: '答题记录',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : _questions.isEmpty
                  ? _buildEmptyWidget()
                  : _buildQuizWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadQuestions,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _allQuestionsCompleted ? Icons.emoji_events : Icons.quiz_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _allQuestionsCompleted ? '恭喜您已完成所有党史题目！' : '暂无党史题目',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_allQuestionsCompleted) ...[
            const SizedBox(height: 8),
            Text(
              '您可以查看答题记录了解详细情况',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizWidget() {
    if (_currentIndex >= _questions.length) {
      return _buildEmptyWidget();
    }

    final currentQuestion = _questions[_currentIndex];

    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 题目信息
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currentQuestion.questionTypeDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      currentQuestion.difficultyDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1}/${_questions.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 题目内容
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                currentQuestion.questionText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 选项区域
            if (!_showAnswer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildOptions(currentQuestion),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildResult(currentQuestion),
              ),
            ],

            const SizedBox(height: 24),

            // AI解答组件（仅在答题错误时显示）
            if (_showAnswer && !_isCorrect) ...[
              AIExplanationWidget(
                question: currentQuestion.toJson(),
                userAnswer: _userAnswers,
                isCorrect: _isCorrect,
                hasAnswered: _showAnswer,
                onRetry: _resetCurrentQuestion,
                quizRecordId: _currentQuizRecordId,
              ),
              const SizedBox(height: 16),
            ],

            // 操作按钮（无论答对答错都显示）
            if (_showAnswer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(_currentIndex < _questions.length - 1 ? '下一题' : '完成'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(QuizQuestion question) {
    if (question.isFillInBlank) {
      return Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: '请输入答案',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (value) {
              _handleAnswer([value]);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // 这里需要获取TextField的值
                _handleAnswer(['']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('提交答案'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: question.options.asMap().entries.map((entry) {
        final option = entry.value;
        final optionText = option['text'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              if (question.isSingleChoice) {
                _handleAnswer([optionText]);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(question.isSingleChoice ? 4 : 12),
                    ),
                    child: question.isSingleChoice
                        ? null
                        : Icon(
                            question.isMultipleChoice ? Icons.check : null,
                            color: Colors.white,
                            size: 16,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optionText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResult(QuizQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 结果提示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isCorrect ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isCorrect ? Colors.green[300]! : Colors.red[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.cancel,
                color: _isCorrect ? Colors.green[600] : Colors.red[600],
              ),
              const SizedBox(width: 8),
              Text(
                _isCorrect ? '回答正确！' : '回答错误',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isCorrect ? Colors.green[600] : Colors.red[600],
                ),
              ),
              const Spacer(),
              Text(
                '$_score分',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isCorrect ? Colors.green[600] : Colors.red[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 正确答案
        if (!_isCorrect) ...[
          Text(
            '正确答案：${question.correctAnswerText}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.green[600],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 解析
        if (question.explanation.isNotEmpty) ...[
          Text(
            '解析',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.explanation,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}