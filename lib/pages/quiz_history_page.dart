import 'package:flutter/material.dart';
import '../services/quiz_history_service.dart';
import '../database/database_helper.dart';
import '../services/ai_explanation_service.dart';
import '../models/ai_explanation.dart';
import 'package:intl/intl.dart';
import 'party_history_quiz_page.dart';

class QuizHistoryPage extends StatefulWidget {
  const QuizHistoryPage({super.key});

  @override
  State<QuizHistoryPage> createState() => _QuizHistoryPageState();
}

class _QuizHistoryPageState extends State<QuizHistoryPage> {
  List<QuizRecord> _allRecords = [];
  List<QuizRecord> _filteredRecords = [];
  QuizStats? _stats;
  bool _isLoading = true;
  String _selectedFilter = '全部'; // 全部、今日、本周、本月

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 从数据库加载答题记录
      final dbHelper = DatabaseHelper();
      final recordMaps = await dbHelper.getQuizRecords(limit: 100);
      final statsMap = await dbHelper.getQuizStats();
      final difficultyStats = await dbHelper.getDifficultyStats();

      // 调试信息
      print('从数据库加载到 ${recordMaps.length} 条答题记录');
      for (var i = 0; i < (recordMaps.length < 3 ? recordMaps.length : 3); i++) {
        final questionText = recordMaps[i]['question_text'] as String?;
        final displayText = questionText != null && questionText.length > 30
            ? '${questionText.substring(0, 30)}...'
            : questionText ?? 'null';
        print('记录 ${i + 1}: $displayText');
      }

      // 转换为QuizRecord对象
      final records = <QuizRecord>[];
      for (var i = 0; i < recordMaps.length; i++) {
        try {
          final record = QuizRecord.fromMap(recordMaps[i]);
          records.add(record);
          print('成功转换记录 ${i + 1}: ${_truncateText(record.questionText)}');
        } catch (e) {
          print('转换记录 ${i + 1} 失败: $e');
          print('问题数据: ${recordMaps[i]}');
        }
      }
      print('成功转换 ${records.length} / ${recordMaps.length} 条记录');

      // 转换为QuizStats对象
      final stats = QuizStats(
        totalQuestions: statsMap['totalQuestions'] ?? 0,
        correctQuestions: statsMap['correctQuestions'] ?? 0,
        totalScore: statsMap['totalScore'] ?? 0,
        totalTimeSpent: statsMap['totalTimeSpent'] ?? 0,
        lastQuizDate: statsMap['lastQuizDate'] ?? DateTime.now(),
        difficultyStats: difficultyStats,
      );

      if (mounted) {
        setState(() {
          _allRecords = records;
          _stats = stats;
          _isLoading = false;
        });
      }

      print('数据加载完成: _allRecords 长度 = ${_allRecords.length}');

      // 确保在setState完成后才调用筛选
      if (mounted) {
        _applyFilter();
      }
    } catch (e) {
      print('从数据库加载答题数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<AIExplanation>> _getAIExplanationsForRecord(QuizRecord record) async {
    if (record.id == null) return [];
    return await AIExplanationService.getAIExplanations(record.id!);
  }

  void _applyFilter() async {
    print('开始应用筛选器: _selectedFilter = $_selectedFilter, _allRecords 长度 = ${_allRecords.length}');

    try {
      List<QuizRecord> filtered;

      switch (_selectedFilter) {
        case '今日':
          final today = DateTime.now();
          final todayStart = DateTime(today.year, today.month, today.day);
          final dbHelper = DatabaseHelper();
          final recordMaps = await dbHelper.getQuizRecordsByDateRange(todayStart, today);
          filtered = recordMaps.map((map) => QuizRecord.fromMap(map)).toList();
          print('今日筛选: 找到 ${filtered.length} 条记录');
          break;
        case '本周':
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final adjustedWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
          final dbHelper = DatabaseHelper();
          final recordMaps = await dbHelper.getQuizRecordsByDateRange(adjustedWeekStart, now);
          filtered = recordMaps.map((map) => QuizRecord.fromMap(map)).toList();
          print('本周筛选: 找到 ${filtered.length} 条记录');
          break;
        case '本月':
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final dbHelper = DatabaseHelper();
          final recordMaps = await dbHelper.getQuizRecordsByDateRange(monthStart, now);
          filtered = recordMaps.map((map) => QuizRecord.fromMap(map)).toList();
          print('本月筛选: 找到 ${filtered.length} 条记录');
          break;
        default:
          filtered = _allRecords;
          print('全部筛选: 使用 _allRecords，长度 = ${filtered.length}');
      }

      print('即将更新UI: _filteredRecords 长度 = ${filtered.length}');
      if (mounted) {
        setState(() {
          _filteredRecords = filtered;
        });
        print('UI更新完成');
      }
    } catch (e) {
      print('应用筛选器失败: $e');
      if (mounted) {
        setState(() {
          _filteredRecords = _allRecords;
        });
        print('使用备选方案: _filteredRecords 长度 = ${_filteredRecords.length}');
      }
    }
  }

  Future<void> _clearHistory() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有答题记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await QuizHistoryService.clearQuizHistory();
                if (mounted) {
                  await _loadQuizData();
                }
              } catch (e) {
                print('清空历史记录失败: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 添加构建时的调试信息
    print('QuizHistoryPage build: _isLoading = $_isLoading, _filteredRecords.length = ${_filteredRecords.length}');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('答题记录'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('清空记录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 统计卡片
                  _buildStatsCard(),
                  const SizedBox(height: 16),

                  // 筛选器
                  _buildFilter(),
                  const SizedBox(height: 16),

                  // 记录列表
                  _filteredRecords.isEmpty
                      ? _buildEmptyState()
                      : _buildRecordsList(),
                  // 调试信息
                  if (!_isLoading) ...[
                    Text(
                      '调试: _filteredRecords 长度 = ${_filteredRecords.length}',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    if (_stats == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '答题统计',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '总答题数',
                  '${_stats!.totalQuestions}',
                  Icons.quiz,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '正确数',
                  '${_stats!.correctQuestions}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '正确率',
                  '${_stats!.accuracyRate.toStringAsFixed(1)}%',
                  Icons.percent,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '总积分',
                  '${_stats!.totalScore}',
                  Icons.emoji_events,
                  Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '平均用时',
                  '${_stats!.averageTimePerQuestion.toStringAsFixed(1)}秒',
                  Icons.timer,
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  '最后答题',
                  DateFormat('MM-dd').format(_stats!.lastQuizDate),
                  Icons.calendar_today,
                  Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ['全部', '今日', '本周', '本月'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
                _applyFilter();
              },
              child: Container(
                margin: EdgeInsets.only(
                  right: filter != '本月' ? 4 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red[600] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.red[600]! : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  filter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无答题记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == '全部'
                ? '开始答题后将显示记录'
                : '该时间段内暂无答题记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_filteredRecords.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        for (int index = 0; index < _filteredRecords.length; index++) ...[
          _buildRecordCard(_filteredRecords[index]),
          if (index < _filteredRecords.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildRecordCard(QuizRecord record) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToQuizPage(record),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: record.isCorrect ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.isCorrect ? '正确' : '错误',
                    style: TextStyle(
                      fontSize: 12,
                      color: record.isCorrect ? Colors.green[700] : Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.difficulty,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '+${record.score}分',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: record.isCorrect ? Colors.green[600] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              record.questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (!record.isCorrect) ...[
              Text(
                '正确答案: ${record.correctAnswer.join(", ")}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '你的答案: ${record.userAnswer.join(", ")}',
              style: TextStyle(
                fontSize: 14,
                color: record.isCorrect ? Colors.green[600] : Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AIExplanation>>(
              future: _getAIExplanationsForRecord(record),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return _buildAIExplanationSection(snapshot.data!.first);
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${record.timeSpent}秒',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(record.answeredAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIExplanationSection(AIExplanation explanation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 16,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 6),
              Text(
                'AI解答',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation.explanation,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue[900],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _truncateText(String? text) {
    if (text == null) return 'null';
    if (text.length > 30) {
      return '${text.substring(0, 30)}...';
    }
    return text;
  }

  void _navigateToQuizPage(QuizRecord record) {
    // 导航回党史题库页面，传递题目ID和从历史记录返回的标记
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PartyHistoryQuizPage(
          fromHistory: true,
        ),
        settings: RouteSettings(
          arguments: {
            'questionId': record.questionId,
            'questionText': record.questionText,
            'questionType': record.questionType,
            'difficulty': record.difficulty,
            'userAnswer': record.userAnswer,
            'correctAnswer': record.correctAnswer,
            'isCorrect': record.isCorrect,
            'fromHistory': true,
          },
        ),
      ),
    );
  }
}