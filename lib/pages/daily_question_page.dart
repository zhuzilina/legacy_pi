import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/ai_service.dart';
import '../services/unified_cache_service.dart';
import '../database/database_helper.dart';
import '../models/user_score.dart';
import '../services/global_state.dart';
import '../models/user.dart';

class DailyQuestionPage extends StatefulWidget {
  const DailyQuestionPage({super.key});

  @override
  State<DailyQuestionPage> createState() => _DailyQuestionPageState();
}

class _DailyQuestionPageState extends State<DailyQuestionPage> {
  Map<String, dynamic>? _question;
  bool _loading = true;
  String _error = '';
  List<String> _userAnswer = [];
  bool _showAnswer = false;
  bool _isCorrect = false;
  bool _hasAnswered = false;
  int _score = 0;
  bool _loadingExplanation = false;
  String _explanation = '';
  bool _showExplanation = false;
  bool _allowRetry = false;
  final AiService _aiService = AiService();
  final UnifiedCacheService _cacheService = UnifiedCacheService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadDailyQuestion();
    _loadSavedState();
  }

  Future<void> _loadDailyQuestion() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final baseUrl = await ApiConfig.knowledgeQuizBaseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/daily-question/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _question = data['data'];
            _loading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? '获取每日一题失败';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = '网络请求失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '请求异常: $e';
        _loading = false;
      });
    }
  }

  Future<void> _checkAnswer() async {
    if (_question == null) return;

    bool isCorrect = false;
    if (_question!['question_type'] == 'choice') {
      // 选择题：检查用户选择的选项
      final correctAnswers = _getCorrectAnswers();
      isCorrect = _userAnswer.length == correctAnswers.length &&
                  _userAnswer.every((answer) => correctAnswers.contains(answer));
    } else if (_question!['question_type'] == 'multiple_choice') {
      // 多选题：检查用户选择的多个选项
      final correctAnswers = _getCorrectAnswers();
      isCorrect = _userAnswer.length == correctAnswers.length &&
                  _userAnswer.every((answer) => correctAnswers.contains(answer));
    } else if (_question!['question_type'] == 'fill') {
      // 填空题：检查用户输入的答案
      isCorrect = _userAnswer.isNotEmpty &&
                  _userAnswer[0].trim().toLowerCase() ==
                  _question!['correct_answer'].toString().trim().toLowerCase();
    }

    setState(() {
      _showAnswer = true;
      _isCorrect = isCorrect;
      _hasAnswered = true;
      _score = isCorrect ? 100 : 60;
    });

    // 保存答题状态
    await _saveAnswerState();

    // 保存积分到数据库
    await _saveScoreToDatabase();

    // 检查是否有缓存的AI解答
    await _checkCachedExplanation();

    // 显示结果弹窗
    _showResultDialog();
  }

  List<String> _getCorrectAnswers() {
    if (_question == null) return [];

    final options = _question!['options'] as List?;
    if (options == null) return [];

    List<String> correctAnswers = [];
    for (var option in options) {
      if (option['is_correct'] == true) {
        correctAnswers.add(option['text'] ?? '');
      }
    }
    return correctAnswers;
  }

  String _getCorrectAnswer() {
    final correctAnswers = _getCorrectAnswers();
    return correctAnswers.isNotEmpty ? correctAnswers.first : '';
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

  // 持久化相关方法
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0]; // 获取今天的日期
      final savedDate = prefs.getString('daily_question_date');
      
      // 如果是同一天且已答题，则恢复状态
      if (savedDate == today) {
        final hasAnswered = prefs.getBool('daily_question_answered') ?? false;
        final userAnswerList = prefs.getStringList('daily_question_answer') ?? [];
        final isCorrect = prefs.getBool('daily_question_correct') ?? false;
        final score = prefs.getInt('daily_question_score') ?? 0;
        
        if (hasAnswered) {
          setState(() {
            _hasAnswered = true;
            _userAnswer = userAnswerList;
            _isCorrect = isCorrect;
            _score = score;
            _showAnswer = true;
          });

          // 检查是否有缓存的AI解答
          await _checkCachedExplanation();
        }
      } else {
        // 如果不是同一天，清除之前的状态
        await _clearSavedState();
      }
    } catch (e) {
      print('加载保存状态失败: $e');
    }
  }

  Future<void> _saveAnswerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      await prefs.setString('daily_question_date', today);
      await prefs.setBool('daily_question_answered', _hasAnswered);
      await prefs.setStringList('daily_question_answer', _userAnswer);
      await prefs.setBool('daily_question_correct', _isCorrect);
      await prefs.setInt('daily_question_score', _score);
    } catch (e) {
      print('保存答题状态失败: $e');
    }
  }

  Future<void> _clearSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('daily_question_date');
      await prefs.remove('daily_question_answered');
      await prefs.remove('daily_question_answer');
      await prefs.remove('daily_question_correct');
      await prefs.remove('daily_question_score');
    } catch (e) {
      print('清除保存状态失败: $e');
    }
  }

  Future<void> _getAIExplanation() async {
    if (_question == null) return;

    setState(() {
      _loadingExplanation = true;
    });

    try {
      // 组织题目、选项和用户答案为文本
      String questionText = _question!['question_text'] ?? '';
      String questionTextContent = '题目：$questionText\n\n';

      // 添加选项
      if (_question!['question_type'] == 'choice' || _question!['question_type'] == 'multiple_choice') {
        questionTextContent += '选项：\n';
        final options = _question!['options'] as List? ?? [];
        for (int i = 0; i < options.length; i++) {
          final option = options[i];
          final optionText = option['text'] ?? '';
          final isCorrect = option['is_correct'] == true;
          final userSelected = _userAnswer.contains(optionText);
          // 只在用户答对时显示正确答案标记，答错时不显示
          questionTextContent += '${String.fromCharCode(65 + i)}. $optionText ${_isCorrect && isCorrect ? '(正确答案)' : ''} ${userSelected ? '(用户选择)' : ''}\n';
        }
        questionTextContent += '\n';
      }

      // 添加用户答案
      questionTextContent += '用户答案：${_userAnswer.join(', ')}\n';
      questionTextContent += '答题结果：${_isCorrect ? '正确' : '错误'}\n';

      // 添加自定义提示词
      final customPrompt = '''
请对以下题目进行详细解答：
1. 分析题目的考点和知识点
2. 解释正确答案的原因
3. 如果用户答错了，分析错误原因
4. 给出相关的知识点延伸和记忆方法
5. 解答要详细、易懂，适合学习使用

题目内容：
''';

      // 生成缓存键
      final questionId = _question!['id']?.toString() ?? questionText;
      final cacheKey = 'daily_question_${questionId}_${_userAnswer.join('_')}';

      print('发送给AI的文本长度: ${questionTextContent.length}');
      print('缓存键: $cacheKey');

      // 首先检查缓存
      final cachedResponse = _cacheService.getAiCache(
        questionTextContent,
        'question_explanation',
        customPrompt
      );

      if (cachedResponse != null && cachedResponse.data != null) {
        print('从缓存获取AI解答成功');
        setState(() {
          _explanation = cachedResponse.data!.interpretation;
          _loadingExplanation = false;
          _showExplanation = true;
          _allowRetry = true;
        });
        return;
      }

      // 没有缓存，调用API
      final response = await _aiService.interpretText(
        text: questionTextContent,
        promptType: 'question_explanation',
        customPrompt: customPrompt,
        maxTokens: 2000,
      );

      if (response != null && response.success && response.data != null) {
        print('AI解答成功 - 结果长度: ${response.data!.interpretation.length}');
        setState(() {
          _explanation = response.data!.interpretation;
          _loadingExplanation = false;
          _showExplanation = true;
          _allowRetry = true;
        });

        // 结果已由AiService自动缓存
      } else {
        print('AI解答失败 - 错误: ${response?.error}');
        setState(() {
          _explanation = '获取AI解答失败: ${response?.error ?? '未知错误'}';
          _loadingExplanation = false;
          _showExplanation = true;
          _allowRetry = true;
        });
      }
    } catch (e) {
      setState(() {
        _explanation = '请求异常: $e';
        _loadingExplanation = false;
        _showExplanation = true;
        _allowRetry = true;
      });
    }
  }

  // 保存积分到数据库
  Future<void> _saveScoreToDatabase() async {
    try {
      if (_currentUser == null) return;

      final dbHelper = DatabaseHelper();

      // 创建积分记录
      final userScore = UserScore(
        userId: _currentUser!.id!,
        score: _score,
        description: _isCorrect ? '每日答题正确获得积分' : '每日答题参与获得积分',
        earnedAt: DateTime.now(),
      );

      // 保存到数据库
      await dbHelper.insertUserScore(userScore);
      print('积分已保存到数据库: 用户${_currentUser!.id} 获得$_score分');
    } catch (e) {
      print('保存积分到数据库失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('每日一答'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorWidget()
              : _question == null
                  ? _buildEmptyWidget()
                  : _buildQuestionWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 24),
            Text(
              _error,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDailyQuestion,
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              '暂无可用题目',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '请稍后再试',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionWidget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目内容和答题区域合并的卡片
          _buildQuestionAndAnswerCard(),
          const SizedBox(height: 20),

          // 分数显示（已答题时显示）
          if (_hasAnswered) ...[
            _buildScoreDisplay(),
            const SizedBox(height: 16),
          ],

          // AI解答区域（仅在答题错误后显示）
          if (_hasAnswered && !_isCorrect) ...[
            _buildAIExplanationSection(),
            const SizedBox(height: 20),
          ],
          // AI解答获取按钮区域（用于重新答题后再次获取）
          if (_allowRetry && !_hasAnswered && _explanation.isNotEmpty) ...[
            _buildAIExplanationSection(),
            const SizedBox(height: 20),
          ],

          // 提交按钮
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildQuestionAndAnswerCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 题目内容
            Text(
              _question!['question_text'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            
            // 答题区域
            _buildAnswerArea(),
          ],
        ),
      ),
    );
  }


  Widget _buildAnswerArea() {
    if (_question!['question_type'] == 'choice' || _question!['question_type'] == 'multiple_choice') {
      return _buildChoiceOptions();
    } else if (_question!['question_type'] == 'fill') {
      return _buildFillAnswer();
    }
    return const SizedBox.shrink();
  }

  Widget _buildChoiceOptions() {
    final options = _question!['options'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '请选择答案：',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
            ...options.asMap().entries.map((entry) {
              final option = entry.value;
              final isSelected = _userAnswer.contains(option['text']);
              final isCorrect = _showAnswer && _isCorrect && option['is_correct'] == true;
              final isWrong = _showAnswer && isSelected && !_isCorrect;
              
              Color borderColor = Colors.grey[300]!;
              Color backgroundColor = Colors.white;
              
              if (_showAnswer) {
                if (isCorrect) {
                  borderColor = Colors.green;
                  backgroundColor = Colors.green[50]!;
                } else if (isWrong) {
                  borderColor = Colors.red;
                  backgroundColor = Colors.red[50]!;
                }
              } else if (isSelected) {
                borderColor = Colors.blue;
                backgroundColor = Colors.blue[50]!;
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: _showAnswer ? null : () {
                    setState(() {
                      if (_userAnswer.contains(option['text'])) {
                        _userAnswer.remove(option['text']);
                      } else {
                        _userAnswer.add(option['text'] ?? '');
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border.all(color: borderColor, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option['text'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              color: isCorrect || isWrong ? Colors.black87 : Colors.black87,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_showAnswer && _isCorrect && isCorrect)
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                        if (_showAnswer && isWrong)
                          Icon(Icons.cancel, color: Colors.red, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }),
      ],
    );
  }

  
  Widget _buildFillAnswer() {
    return TextField(
      enabled: !_hasAnswered,
      controller: TextEditingController(text: _userAnswer.isNotEmpty ? _userAnswer[0] : ''),
      onChanged: (value) {
        if (!_hasAnswered) {
          setState(() {
            _userAnswer = [value];
          });
        }
      },
      decoration: InputDecoration(
        hintText: _hasAnswered ? '' : '请输入答案...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      maxLines: 3,
    );
  }

  Widget _buildSubmitButton() {
    // 如果用户已经答错，不显示任何按钮
    if (_hasAnswered && !_isCorrect) {
      return const SizedBox.shrink();
    }

    // 如果用户使用了AI解答并允许重试，显示重新答题的按钮样式
    if (_allowRetry && !_hasAnswered) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            if (_userAnswer.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请先选择或输入答案')),
              );
              return;
            }
            _checkAnswer();
          },
          icon: const Icon(Icons.redo),
          label: const Text('重新提交答案', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      );
    }

    // 正常的提交按钮（答对时显示"已答题"，未答题时显示"提交答案"）
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _hasAnswered && _isCorrect ? null : () {
          if (_userAnswer.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先选择或输入答案')),
            );
            return;
          }
          _checkAnswer();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          _hasAnswered && _isCorrect ? '已答题' : '提交答案',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildScoreDisplay() {
    return Center(
      child: Text(
        '$_score分',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _isCorrect ? Theme.of(context).primaryColor : Colors.grey[600],
        ),
      ),
    );
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 分数显示
            Text(
              '$_score分',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _isCorrect ? Theme.of(context).primaryColor : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),

            // 结果文字
            Text(
              _isCorrect ? '回答正确' : '回答错误',
              style: TextStyle(
                fontSize: 16,
                color: _isCorrect ? Theme.of(context).primaryColor : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // 按钮区域
            if (_isCorrect) ...[
              // 回答正确：只有确定按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('确定'),
                ),
              ),
            ] else ...[
              // 回答错误：返回和继续学习按钮
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // 按钮行
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('返回'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // 继续学习逻辑暂时不考虑
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('继续学习'),
                        ),
                      ),
                    ],
                  ),
                  // "拿100分"文字悬浮在继续学习按钮右上角
                  Positioned(
                    top: -12,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '拿100分',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAIExplanationSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI解答标题栏
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI智能解答',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        '学习加50积分',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!_showExplanation) ...[
              const SizedBox(height: 16),
              // 获取AI解答按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loadingExplanation ? null : _getAIExplanation,
                  icon: _loadingExplanation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.smart_toy),
                  label: _loadingExplanation
                      ? const Text('获取中...', style: TextStyle(fontSize: 16))
                      : const Text('获取AI解答', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              // AI解答内容
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.blue[300],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI解析内容',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        if (_explanation.isNotEmpty)
                          Text(
                            'AI生成内容，仅供参考',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingExplanation)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'AI正在为您生成详细解答...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_explanation.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _explanation,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 重新答题按钮
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _resetAnswer,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重新答题', style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 检查是否有缓存的AI解答
  Future<void> _checkCachedExplanation() async {
    if (_question == null || _userAnswer.isEmpty) return;

    try {
      // 组织题目、选项和用户答案为文本（与_getAIExplanation保持一致）
      String questionText = _question!['question_text'] ?? '';
      String questionTextContent = '题目：$questionText\n\n';

      // 添加选项
      if (_question!['question_type'] == 'choice' || _question!['question_type'] == 'multiple_choice') {
        questionTextContent += '选项：\n';
        final options = _question!['options'] as List? ?? [];
        for (int i = 0; i < options.length; i++) {
          final option = options[i];
          final optionText = option['text'] ?? '';
          final isCorrect = option['is_correct'] == true;
          final userSelected = _userAnswer.contains(optionText);
          questionTextContent += '${String.fromCharCode(65 + i)}. $optionText ${_isCorrect && isCorrect ? '(正确答案)' : ''} ${userSelected ? '(用户选择)' : ''}\n';
        }
        questionTextContent += '\n';
      }

      // 添加用户答案
      questionTextContent += '用户答案：${_userAnswer.join(', ')}\n';
      questionTextContent += '答题结果：${_isCorrect ? '正确' : '错误'}\n';

      // 添加自定义提示词
      final customPrompt = '''
请对以下题目进行详细解答：
1. 分析题目的考点和知识点
2. 解释正确答案的原因
3. 如果用户答错了，分析错误原因
4. 给出相关的知识点延伸和记忆方法
5. 解答要详细、易懂，适合学习使用

题目内容：
''';

      // 检查缓存
      final cachedResponse = _cacheService.getAiCache(
        questionTextContent,
        'question_explanation',
        customPrompt
      );

      if (cachedResponse != null && cachedResponse.data != null) {
        print('发现缓存的AI解答');
        setState(() {
          _explanation = cachedResponse.data!.interpretation;
          _allowRetry = true;
          // 如果用户已答错，直接显示AI解答区域
          if (_hasAnswered && !_isCorrect) {
            _showExplanation = true;
          }
        });
      }
    } catch (e) {
      print('检查缓存失败: $e');
    }
  }

  // 重置答题状态，允许用户重新答题
  void _resetAnswer() {
    setState(() {
      _userAnswer = [];
      _showAnswer = false;
      _hasAnswered = false;
      _isCorrect = false;
      _score = 0;
      _allowRetry = false;
      // 保留AI解答内容，但隐藏显示区域
      _showExplanation = false;
    });
  }
}
