import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class DailyQuestionPage extends StatefulWidget {
  const DailyQuestionPage({super.key});

  @override
  State<DailyQuestionPage> createState() => _DailyQuestionPageState();
}

class _DailyQuestionPageState extends State<DailyQuestionPage> {
  Map<String, dynamic>? _question;
  bool _loading = true;
  String _error = '';
  String _userAnswer = '';
  bool _showAnswer = false;
  bool _isCorrect = false;
  bool _hasAnswered = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
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
      isCorrect = _userAnswer == _getCorrectAnswer();
    } else if (_question!['question_type'] == 'fill') {
      // 填空题：检查用户输入的答案
      isCorrect = _userAnswer.trim().toLowerCase() == 
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

    // 显示结果弹窗
    _showResultDialog();
  }

  String _getCorrectAnswer() {
    if (_question == null) return '';
    
    final options = _question!['options'] as List?;
    if (options == null) return '';
    
    for (var option in options) {
      if (option['is_correct'] == true) {
        return option['text'] ?? '';
      }
    }
    return '';
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
        final userAnswer = prefs.getString('daily_question_answer') ?? '';
        final isCorrect = prefs.getBool('daily_question_correct') ?? false;
        final score = prefs.getInt('daily_question_score') ?? 0;
        
        if (hasAnswered) {
          setState(() {
            _hasAnswered = true;
            _userAnswer = userAnswer;
            _isCorrect = isCorrect;
            _score = score;
            _showAnswer = true;
          });
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
      await prefs.setString('daily_question_answer', _userAnswer);
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
    if (_question!['question_type'] == 'choice') {
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
          '请选择正确答案：',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
            ...options.asMap().entries.map((entry) {
              final option = entry.value;
              final isSelected = _userAnswer == option['text'];
              final isCorrect = _showAnswer && option['is_correct'] == true;
              final isWrong = _showAnswer && isSelected && !isCorrect;
              
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
                      _userAnswer = option['text'] ?? '';
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
                            borderRadius: BorderRadius.circular(12),
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
                        if (_showAnswer && isCorrect)
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                        if (_showAnswer && isWrong)
                          Icon(Icons.cancel, color: Colors.red, size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ],
    );
  }

  Widget _buildFillAnswer() {
    return TextField(
      enabled: !_hasAnswered,
      controller: TextEditingController(text: _userAnswer),
      onChanged: (value) {
        if (!_hasAnswered) {
          setState(() {
            _userAnswer = value;
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _hasAnswered ? null : () {
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
          _hasAnswered ? '已答题' : '提交答案',
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
}
