import 'package:flutter/material.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    startTimer();
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
    } else {
      submitAnswer();
    }
  }

  void prevQuestion() {
    if (currentQ > 0) {
      setState(() {
        currentQ--;
      });
    }
  }

  void selectAnswer(int index) {
    setState(() {
      userAnswers[currentQ] = index;
    });

    // 自动跳转下一题
    if (currentQ < questions.length - 1) {
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
            // 控制栏
            if (!showResult) _buildControlBar(),
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
    final accuracy = (correctCount / questions.length * 100).round();

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
                  '答题统计',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$accuracy%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              '正确率',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              formatTime(timeUsed),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              '用时',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: accuracy / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            '正确 $correctCount',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            '错误 ${questions.length - correctCount}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
                      child: const Text('重新开始', style: TextStyle(fontSize: 16)),
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

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: prevQuestion,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('上一题'),
          ),
          ElevatedButton(
            onPressed: userAnswers[currentQ] != null ? nextQuestion : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              currentQ == questions.length - 1 ? '提交答案' : '下一题',
            ),
          ),
        ],
      ),
    );
  }
}