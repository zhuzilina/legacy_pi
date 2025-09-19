import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:legacy_pi/services/global_state.dart';
import 'package:legacy_pi/models/user.dart';
import 'package:legacy_pi/database/database_helper.dart';
import 'package:legacy_pi/models/user_score.dart';

class DailyQuizPage extends StatefulWidget {
  const DailyQuizPage({super.key,required this.title});

  final String? title;
  @override
  _DailyQuizPageState createState() => _DailyQuizPageState();
}

class _DailyQuizPageState extends State<DailyQuizPage> {
  List<Map<String, dynamic>> questions = [
    {
      'type': '单选题',
      'title': '中国过去一切革命斗争成效甚少的基本原因是（  ）',
      'options': [
        'A. 革命党没有正确的理论指导',
        'B. 不能团结真正的朋友，以攻击真正的敌人',
        'C. 群众没有积极参与革命',
        'D. 帝国主义势力过于强大'
      ],
      'answer': 1 // B
    },
    {
      'type': '单选题',
      'title': '革命党在革命中的重要作用是（  ）',
      'options': [
        'A. 发动群众进行斗争',
        'B. 为革命提供资金支持',
        'C. 作为群众的向导',
        'D. 制定革命的具体策略'
      ],
      'answer': 2 // C
    },
    {
      'type': '单选题',
      'title': '地主阶级和买办阶级在半殖民地中国的地位是（  ）',
      'options': [
        'A. 独立发展的阶级',
        'B. 代表先进生产关系的阶级',
        'C. 国际资产阶级的附庸',
        'D. 推动中国生产力发展的阶级'
      ],
      'answer': 2 // C
    },
    {
      'type': '单选题',
      'title': '在中国，代表最落后和最反动生产关系，阻碍中国生产力发展的阶级是（  ）',
      'options': [
        'A. 民族资产阶级',
        'B. 小资产阶级',
        'C. 地主阶级和买办阶级',
        'D. 无产阶级'
      ],
      'answer': 2 // C
    },
    {
      'type': '单选题',
      'title': '大地主阶级和大买办阶级的政治代表是（  ）',
      'options': [
        'A. 国家主义派和国民党左派',
        'B. 国家主义派和国民党右派',
        'C. 共产党和国民党左派',
        'D. 共产党和国民党右派'
      ],
      'answer': 1 // B
    }
  ];

  int currentQ = 0;
  List<int?> userAnswers = List.filled(5, null);
  int remainingTime = 180; // 12分钟（720秒）缩短为3分钟便于测试
  late Timer timer;
  bool showResult = false;
  int correctCount = 0;
  int timeUsed = 0;

  // 用户相关
  User? _currentUser;
  String? _userAvatarPath;
  static const String _opponentName = '努力的大明'; // 对手昵称
  static const String _opponentAvatar = 'assets/images/avatar1.png'; // 对手头像
  static const int _opponentCorrectCount = 3; // 对手答对题数

  @override
  void initState() {
    super.initState();
    _initializeUserAndAvatar();
    startTimer();
  }

  // 初始化用户和头像
  Future<void> _initializeUserAndAvatar() async {
    try {
      // 从全局状态获取用户
      final globalState = GlobalState();
      _currentUser = globalState.currentUser;

      // 如果全局状态没有用户数据，从SQLite数据库读取
      if (_currentUser == null) {
        await _loadUserFromDatabase();
      }

      // 加载用户头像
      await _loadUserAvatar();
    } catch (e) {
      debugPrint('初始化用户和头像失败: $e');
    }
  }

  // 从SQLite数据库读取用户数据
  Future<void> _loadUserFromDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      // 获取数据库中的第一个用户作为当前用户
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
        debugPrint('从数据库加载用户数据: ${_currentUser?.username}');
      } else {
        // 如果数据库中没有用户数据，使用默认用户
        setState(() {
          _currentUser = User(
            id: 1,
            username: '当前用户',
            email: 'user@example.com',
            avatarPath: null,
            nickname: '当前用户',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });
        debugPrint('数据库中没有用户数据，使用默认用户');
      }
    } catch (e) {
      debugPrint('从数据库加载用户数据失败: $e');
      // 发生错误时使用默认用户
      setState(() {
        _currentUser = User(
          id: 1,
          username: '当前用户',
          email: 'user@example.com',
          avatarPath: null,
          nickname: '当前用户',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  // 加载用户头像
  Future<void> _loadUserAvatar() async {
    try {
      if (_currentUser != null && _currentUser!.avatarPath != null) {
        setState(() {
          _userAvatarPath = _currentUser!.avatarPath;
        });
        debugPrint('从数据库加载用户头像: $_userAvatarPath');
      }
    } catch (e) {
      debugPrint('加载用户头像失败: $e');
    }
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        if (remainingTime > 0 && !showResult) {
          remainingTime--;
        } else if (!showResult) {
          submitAnswer();
        }
      });
    });
  }

  void nextQuestion() {
    if (userAnswers[currentQ] == null) return;

    if (currentQ < questions.length - 1) {
      setState(() {
        currentQ++;
      });
    }
  }

  void selectAnswer(int index) {
    setState(() {
      userAnswers[currentQ] = index;
    });

    // 如果是最后一题，直接提交答案
    if (currentQ == questions.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), submitAnswer);
    } else {
      // 否则自动跳转下一题
      Future.delayed(const Duration(milliseconds: 500), nextQuestion);
    }
  }

  void submitAnswer() {
    timer.cancel();
    correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      if (userAnswers[i] == questions[i]['answer']) {
        correctCount++;
      }
    }
    timeUsed = 180 - remainingTime;

    // 保存积分到数据库
    _saveScoreToDatabase();

    setState(() {
      showResult = true;
    });
  }

  // 新增：重置答题状态
  void restartQuiz() {
    setState(() {
      currentQ = 0;
      userAnswers = List.filled(5, null);
      remainingTime = 180;
      showResult = false;
      correctCount = 0;
      timeUsed = 0;
    });
    startTimer();
  }

  // 保存积分到数据库
  Future<void> _saveScoreToDatabase() async {
    try {
      if (_currentUser == null) return;

      final dbHelper = DatabaseHelper();
      final scoreAmount = correctCount * 10; // 每题10分

      // 创建积分记录
      final userScore = UserScore(
        userId: _currentUser!.id!,
        score: scoreAmount,
        description: 'PK答题获得积分 - 答对$correctCount题',
        earnedAt: DateTime.now(),
      );

      // 保存到数据库
      await dbHelper.insertUserScore(userScore);
      debugPrint('积分已保存到数据库: 用户${_currentUser!.id} 获得$scoreAmount分');
    } catch (e) {
      debugPrint('保存积分到数据库失败: $e');
    }
  }

  String formatTime(int seconds) {
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: widget.title==null?const Text('每日一答'):Text('Pk答题'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 状态栏
            _buildStatusBar(),
            // 主要内容区
            Expanded(
              child: showResult ? _buildResultArea() : _buildQuestionArea(),
            ),
            // 进度条
            _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${currentQ + 1}/${questions.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '剩余时间 ${formatTime(remainingTime)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionArea() {
    final currentQuestion = questions[currentQ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentQuestion['type'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  currentQuestion['title'],
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 25),
                ...List.generate(
                  currentQuestion['options'].length,
                      (index) => GestureDetector(
                    onTap: () => selectAnswer(index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: userAnswers[currentQ] == index ? Colors.blue[50] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: userAnswers[currentQ] == index ? Colors.blue : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: userAnswers[currentQ] == index ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: userAnswers[currentQ] == index
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
                              currentQuestion['options'][index],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: userAnswers[currentQ] == index ? Colors.blue : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    final bool isWinner = correctCount > _opponentCorrectCount;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: const Text(
                  'PK结果',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 用户对战信息
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 用户信息
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            child: _userAvatarPath != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(_userAvatarPath!),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.person,
                                          size: 30,
                                          color: Colors.grey[600],
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUser?.nickname ?? _currentUser?.username ?? '我',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            '答对 $correctCount 题',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // VS
                    Column(
                      children: [
                        const Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          isWinner ? Icons.emoji_events : Icons.sentiment_neutral,
                          color: isWinner ? Colors.amber : Colors.grey,
                          size: 24,
                        ),
                      ],
                    ),
                    // 对手信息
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage(_opponentAvatar),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _opponentName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            '答对 $_opponentCorrectCount 题',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    // 显示积分情况
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '+${correctCount * 10}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '我的积分',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '+${_opponentCorrectCount * 10}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '对手积分',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 新增返回按钮
                    ElevatedButton(
                      onPressed: restartQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('再来一局', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (currentQ + 1) / questions.length,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  }