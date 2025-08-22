import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/user_score.dart';

class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ZoomableBackgroundWidget());
  }
}

class ZoomableBackgroundWidget extends StatefulWidget {
  const ZoomableBackgroundWidget({super.key});

  @override
  State<ZoomableBackgroundWidget> createState() =>
      _ZoomableBackgroundWidgetState();
}

class _ZoomableBackgroundWidgetState extends State<ZoomableBackgroundWidget> {
  // 单选按钮数据
  final List<RadioButtonData> _radioButtons = [];
  String? _selectedValue;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 存储键名
  static const String _storageKey = 'journey_button_positions';

  // 气泡状态管理
  String? _activeBubbleButtonId; // 当前显示气泡的按钮ID

  // 数据库和用户管理
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;
  int _totalScore = 120; // 默认积分值，将从数据库读取

  @override
  void initState() {
    super.initState();
    _initializeUserAndDatabase();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 初始化用户和数据库
  Future<void> _initializeUserAndDatabase() async {
    try {
      // 初始化数据库
      await _databaseHelper.database;

      // 尝试获取默认用户，如果不存在则创建
      _currentUser = await _databaseHelper.getUserByUsername('default_user');

      if (_currentUser == null) {
        // 创建默认用户
        final now = DateTime.now();
        final newUser = User(
          username: 'default_user',
          email: 'default@example.com',
          createdAt: now,
          updatedAt: now,
        );

        final userId = await _databaseHelper.insertUser(newUser);
        _currentUser = newUser.copyWith(id: userId);

        // 为新用户添加初始积分
        await _databaseHelper.insertUserScore(
          UserScore(
            userId: userId,
            score: 120,
            description: '初始积分',
            earnedAt: now,
          ),
        );
      }

      // 加载用户总积分
      if (_currentUser != null) {
        _totalScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );
      }

      // 加载按钮位置
      _loadOrGenerateButtonPositions();
    } catch (e) {
      print('初始化数据库失败: $e');
      // 如果数据库初始化失败，使用默认值
      _totalScore = 120;
      _loadOrGenerateButtonPositions();
    }
  }

  // 加载或生成按钮位置
  Future<void> _loadOrGenerateButtonPositions() async {
    try {
      // 尝试从本地存储加载按钮位置
      final prefs = await SharedPreferences.getInstance();
      final savedPositionsJson = prefs.getString(_storageKey);

      if (savedPositionsJson != null) {
        // 如果有保存的位置，则加载
        final List<dynamic> savedPositions = jsonDecode(savedPositionsJson);
        _radioButtons.clear();

        for (final positionData in savedPositions) {
          _radioButtons.add(RadioButtonData.fromJson(positionData));
        }

        setState(() {});

        // 延迟滚动到覆盖层结尾处
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToOverlayEnd();
        });
      } else {
        // 如果没有保存的位置，则生成新的
        _generateRandomRadioButtons();
      }
    } catch (e) {
      // 如果加载失败，则生成新的
      print('加载按钮位置失败: $e');
      _generateRandomRadioButtons();
    }
  }

  void _generateRandomRadioButtons() {
    final random = Random();

    // 获取屏幕尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;

      // 计算可用宽度（屏幕宽度减去左右边距）
      final margin = size.width * 0.25; // 左右各25%边距
      final availableWidth = size.width - (margin * 2); // 可用宽度
      final startX = margin; // 左边距

      // 生成100个按钮，沿Y轴等距分布，X轴随机
      for (int i = 0; i < 100; i++) {
        // Y轴等距分布，间距115像素（110-120的平均值）
        // 从容器底部开始，向上分布
        final yPosition = (size.height + 11500) - 50.0 - (i * 115.0);

        // X轴随机分布
        final xPosition = startX + (random.nextDouble() * availableWidth);

        _radioButtons.add(
          RadioButtonData(
            value: '选项${i + 1}', // 使用简单的选项名称
            position: Offset(xPosition, yPosition),
          ),
        );
      }

      // 保存新生成的位置
      _saveButtonPositions();

      setState(() {}); // 重新构建UI

      // 延迟滚动到覆盖层结尾处，确保布局完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToOverlayEnd();
      });
    });
  }

  // 保存按钮位置到本地存储
  Future<void> _saveButtonPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionsJson = jsonEncode(
        _radioButtons.map((btn) => btn.toJson()).toList(),
      );
      await prefs.setString(_storageKey, positionsJson);
    } catch (e) {
      print('保存按钮位置失败: $e');
    }
  }

  // 滚动到覆盖层结尾处
  void _scrollToOverlayEnd() {
    if (!_scrollController.hasClients || _radioButtons.isEmpty) return;

    // 计算覆盖层结尾位置，使用与覆盖层结尾大按钮相同的算法
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 100;
    final coveredButtons = (totalWeight / weightPerButton).floor();
    final remainingWeight = totalWeight % weightPerButton;

    Offset endPosition;
    if (remainingWeight > 0 && coveredButtons < _radioButtons.length - 1) {
      // 有部分覆盖，使用贝塞尔曲线精确计算结尾位置
      final previousButton = _radioButtons[coveredButtons];
      final currentButton = _radioButtons[coveredButtons + 1];
      final remainingRatio = remainingWeight / weightPerButton; // 0.5比例

      final dx = currentButton.position.dx - previousButton.position.dx;
      final dy = currentButton.position.dy - previousButton.position.dy;
      final distance = sqrt(dx * dx + dy * dy);

      // 使用与覆盖层相同的贝塞尔曲线算法
      // 计算曲度
      double curvature = 0.0;
      final i = coveredButtons + 1;
      if (i > 1 && i < _radioButtons.length - 1) {
        final prevPrevButton = _radioButtons[i - 2];
        final nextButton = _radioButtons[i + 1];

        final prevDirection = Offset(
          previousButton.position.dx - prevPrevButton.position.dx,
          previousButton.position.dy - prevPrevButton.position.dy,
        );
        final nextDirection = Offset(
          nextButton.position.dx - currentButton.position.dx,
          nextButton.position.dy - currentButton.position.dy,
        );

        final prevLength = sqrt(
          prevDirection.dx * prevDirection.dx +
              prevDirection.dy * prevDirection.dy,
        );
        final nextLength = sqrt(
          nextDirection.dx * nextDirection.dx +
              nextDirection.dy * nextDirection.dy,
        );

        if (prevLength > 0 && nextLength > 0) {
          final dotProduct =
              (prevDirection.dx * nextDirection.dx +
                  prevDirection.dy * nextDirection.dy) /
              (prevLength * nextLength);
          final clampedDot = dotProduct.clamp(-1.0, 1.0);
          curvature = acos(clampedDot);
        }
      }

      // 计算自适应距离
      final baseFactor = 0.4;
      final curvatureFactor = curvature / pi;
      final adaptiveDistance = distance * (baseFactor + curvatureFactor * 0.3);

      // 计算切线方向
      Offset previousTangent = Offset(dx / distance, dy / distance);
      if (i > 1) {
        final prevPrevButton = _radioButtons[i - 2];
        final prevDx = previousButton.position.dx - prevPrevButton.position.dx;
        final prevDy = previousButton.position.dy - prevPrevButton.position.dy;
        final prevDistance = sqrt(prevDx * prevDx + prevDy * prevDy);
        if (prevDistance > 0) {
          final prevTangent = Offset(
            prevDx / prevDistance,
            prevDy / prevDistance,
          );
          final currentDirection = Offset(dx / distance, dy / distance);

          final weight = 0.7;
          previousTangent = Offset(
            currentDirection.dx * weight + prevTangent.dx * (1 - weight),
            currentDirection.dy * weight + prevTangent.dy * (1 - weight),
          );

          final tangentLength = sqrt(
            previousTangent.dx * previousTangent.dx +
                previousTangent.dy * previousTangent.dy,
          );
          if (tangentLength > 0) {
            previousTangent = Offset(
              previousTangent.dx / tangentLength,
              previousTangent.dy / tangentLength,
            );
          }
        }
      }

      Offset currentTangent = Offset(dx / distance, dy / distance);
      if (i < _radioButtons.length - 1) {
        final nextButton = _radioButtons[i + 1];
        final nextDx = nextButton.position.dx - currentButton.position.dx;
        final nextDy = nextButton.position.dy - currentButton.position.dy;
        final nextDistance = sqrt(nextDx * nextDx + nextDy * nextDy);
        if (nextDistance > 0) {
          final nextTangent = Offset(
            nextDx / nextDistance,
            nextDy / nextDistance,
          );

          final weight = 0.7;
          currentTangent = Offset(
            currentTangent.dx * weight + nextTangent.dx * (1 - weight),
            currentTangent.dy * weight + nextTangent.dy * (1 - weight),
          );

          final tangentLength = sqrt(
            currentTangent.dx * currentTangent.dx +
                currentTangent.dy * currentTangent.dy,
          );
          if (tangentLength > 0) {
            currentTangent = Offset(
              currentTangent.dx / tangentLength,
              currentTangent.dy / tangentLength,
            );
          }
        }
      }

      // 计算贝塞尔曲线控制点
      final fullControlPoint1 = Offset(
        previousButton.position.dx + previousTangent.dx * adaptiveDistance,
        previousButton.position.dy + previousTangent.dy * adaptiveDistance,
      );
      final fullControlPoint2 = Offset(
        currentButton.position.dx - currentTangent.dx * adaptiveDistance,
        currentButton.position.dy - currentTangent.dy * adaptiveDistance,
      );

      // 使用贝塞尔曲线公式计算精确的结尾位置
      endPosition = _getBezierPointForEndButton(
        previousButton.position,
        fullControlPoint1,
        fullControlPoint2,
        currentButton.position,
        remainingRatio,
      );
    } else {
      // 完整覆盖到某个按钮，使用该按钮的位置
      final endButtonIndex = (coveredButtons - 1).clamp(
        0,
        _radioButtons.length - 1,
      );
      endPosition = _radioButtons[endButtonIndex].position;
    }

    // 计算滚动位置（减去屏幕高度的一半，让覆盖层结尾在屏幕中央）
    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset = endPosition.dy - screenHeight / 2;

    // 确保滚动位置在有效范围内
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final clampedOffset = scrollOffset.clamp(0.0, maxScrollExtent);

    // 执行滚动动画
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  // 重置按钮位置
  Future<void> _resetButtonPositions() async {
    try {
      // 清除本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);

      // 清空当前按钮列表
      _radioButtons.clear();
      setState(() {});

      // 重新生成按钮位置
      _generateRandomRadioButtons();
    } catch (e) {
      print('重置按钮位置失败: $e');
    }
  }

  // 增加用户积分
  Future<void> _addUserScore(int points, String description) async {
    if (_currentUser == null) return;

    try {
      // 添加积分记录
      await _databaseHelper.insertUserScore(
        UserScore(
          userId: _currentUser!.id!,
          score: points,
          description: description,
          earnedAt: DateTime.now(),
        ),
      );

      // 更新总积分
      _totalScore = await _databaseHelper.getTotalUserScore(_currentUser!.id!);

      // 检查并解锁成就
      await _checkAndUnlockAchievements();

      // 刷新UI以反映新的覆盖层长度
      setState(() {});

      print('积分已增加: +$points ($description), 总积分: $_totalScore');
    } catch (e) {
      print('增加积分失败: $e');
    }
  }

  // 检查并解锁成就
  Future<void> _checkAndUnlockAchievements() async {
    if (_currentUser == null) return;

    try {
      // 积分相关成就
      if (_totalScore >= 100 && _totalScore < 200) {
        await _databaseHelper.unlockAchievement(
          _currentUser!.id!,
          '积分新手',
          '获得100积分',
          '🎯',
        );
      } else if (_totalScore >= 500 && _totalScore < 1000) {
        await _databaseHelper.unlockAchievement(
          _currentUser!.id!,
          '积分达人',
          '获得500积分',
          '🏆',
        );
      } else if (_totalScore >= 1000) {
        await _databaseHelper.unlockAchievement(
          _currentUser!.id!,
          '积分大师',
          '获得1000积分',
          '👑',
        );
      }

      // 按钮点击相关成就
      final activeButtonsCount = _radioButtons.where((btn) {
        final buttonIndex = _radioButtons.indexOf(btn);
        final totalWeight = _totalScore;
        final weightPerButton = 100;
        final coveredButtons = (totalWeight / weightPerButton).floor();
        final remainingWeight = totalWeight % weightPerButton;
        return buttonIndex < coveredButtons ||
            (buttonIndex == coveredButtons && remainingWeight > 0);
      }).length;

      if (activeButtonsCount >= 5) {
        await _databaseHelper.unlockAchievement(
          _currentUser!.id!,
          '探索者',
          '激活5个按钮',
          '🔍',
        );
      }

      if (activeButtonsCount >= 10) {
        await _databaseHelper.unlockAchievement(
          _currentUser!.id!,
          '冒险家',
          '激活10个按钮',
          '🗺️',
        );
      }
    } catch (e) {
      print('检查成就失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // 点击其他位置收起气泡
          if (_activeBubbleButtonId != null) {
            setState(() {
              _activeBubbleButtonId = null;
            });
          }
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height:
                    MediaQuery.of(context).size.height +
                    11500, // 100个按钮 * 115像素间距
                child: Stack(
                  children: [
                    // 贝塞尔曲线连接线
                    CustomPaint(
                      size: Size(
                        MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height + 11500,
                      ),
                      painter: BezierCurvePainter(_radioButtons),
                    ),
                    // 贝塞尔曲线覆盖层
                    CustomPaint(
                      size: Size(
                        MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height + 11500,
                      ),
                      painter: BezierCurveOverlayPainter(
                        _radioButtons,
                        _totalScore,
                      ),
                    ),
                    // 随机分布的单选按钮
                    ..._radioButtons.map(
                      (radioData) => _buildRadioButton(radioData),
                    ),
                    // 覆盖层结尾处的大按钮
                    _buildOverlayEndButton(),
                    // 覆盖层结尾按钮的气泡
                    _buildBubbleForEndButton(),
                    // 激活按钮的气泡
                    _buildActiveButtonBubble(),
                  ],
                ),
              ),
            ),
            // 重置按钮
            Positioned(
              top: 50,
              right: 20,
              child: FloatingActionButton(
                onPressed: _resetButtonPositions,
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                child: const Icon(Icons.refresh),
              ),
            ),
            // 增加积分按钮
            Positioned(
              top: 120,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => _addUserScore(100, '手动增加'),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            ),
            // 显示当前积分
            Positioned(
              top: 190,
              right: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '积分: $_totalScore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioButton(RadioButtonData radioData) {
    final buttonSize = 30.0; // 调整为30像素

    // 计算按钮索引
    final buttonIndex = _radioButtons.indexOf(radioData);

    // 计算覆盖层是否经过此按钮
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 100;
    final coveredButtons = (totalWeight / weightPerButton).floor();
    final remainingWeight = totalWeight % weightPerButton;
    final isInOverlay =
        buttonIndex < coveredButtons ||
        (buttonIndex == coveredButtons && remainingWeight > 0);

    // 判断按钮是否激活：用户手动选择或覆盖层经过
    final isActive = _selectedValue == radioData.value || isInOverlay;

    return Positioned(
      left: radioData.position.dx - buttonSize / 2, // 居中定位
      top: radioData.position.dy - buttonSize / 2, // 居中定位
      child: GestureDetector(
        onTap: isActive
            ? () {
                setState(() {
                  _selectedValue = radioData.value;
                  // 切换气泡显示状态
                  if (_activeBubbleButtonId == radioData.value) {
                    _activeBubbleButtonId = null; // 如果已经显示，则隐藏
                  } else {
                    _activeBubbleButtonId = radioData.value; // 否则显示气泡
                  }
                });
              }
            : null, // 未激活时禁用点击事件
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Color(0xFFFFF8DC) // 激活时淡金色填充（偏白色）
                : Colors.white, // 未激活时白色填充
            border: Border.all(
              color: isActive
                  ? Colors
                        .red // 激活时红色边框
                  : Colors.grey.withOpacity(0.5), // 未激活时50%灰色边框
              width: 2.0, // 2像素边框
            ),
          ),
          child: isActive
              ? Icon(
                  Icons.flag, // 小旗帜图标
                  size: buttonSize * 0.6,
                  color: Colors.red, // 红色旗帜
                )
              : null, // 未选中时不显示图标
        ),
      ),
    );
  }

  // 构建覆盖层结尾处的大按钮
  Widget _buildOverlayEndButton() {
    if (_radioButtons.isEmpty) return Container();

    // 添加调试信息
    print('构建覆盖层结尾按钮，按钮数量: ${_radioButtons.length}');

    // 计算覆盖层结尾位置
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 100;
    final coveredButtons = (totalWeight / weightPerButton).floor();
    final remainingWeight = totalWeight % weightPerButton;
    final remainingRatio = remainingWeight / weightPerButton;

    // 确定结尾按钮的位置，使用与覆盖层相同的贝塞尔曲线计算
    Offset endPosition;
    if (remainingWeight > 0 && coveredButtons < _radioButtons.length - 1) {
      // 有部分覆盖，使用贝塞尔曲线精确计算结尾位置
      final previousButton = _radioButtons[coveredButtons];
      final currentButton = _radioButtons[coveredButtons + 1];

      final dx = currentButton.position.dx - previousButton.position.dx;
      final dy = currentButton.position.dy - previousButton.position.dy;
      final distance = sqrt(dx * dx + dy * dy);

      // 使用与覆盖层相同的贝塞尔曲线算法
      // 计算曲度
      double curvature = 0.0;
      final i = coveredButtons + 1;
      if (i > 1 && i < _radioButtons.length - 1) {
        final prevPrevButton = _radioButtons[i - 2];
        final nextButton = _radioButtons[i + 1];

        final prevDirection = Offset(
          previousButton.position.dx - prevPrevButton.position.dx,
          previousButton.position.dy - prevPrevButton.position.dy,
        );
        final nextDirection = Offset(
          nextButton.position.dx - currentButton.position.dx,
          nextButton.position.dy - currentButton.position.dy,
        );

        final prevLength = sqrt(
          prevDirection.dx * prevDirection.dx +
              prevDirection.dy * prevDirection.dy,
        );
        final nextLength = sqrt(
          nextDirection.dx * nextDirection.dx +
              nextDirection.dy * nextDirection.dy,
        );

        if (prevLength > 0 && nextLength > 0) {
          final dotProduct =
              (prevDirection.dx * nextDirection.dx +
                  prevDirection.dy * nextDirection.dy) /
              (prevLength * nextLength);
          final clampedDot = dotProduct.clamp(-1.0, 1.0);
          curvature = acos(clampedDot);
        }
      }

      // 计算自适应距离
      final baseFactor = 0.4;
      final curvatureFactor = curvature / pi;
      final adaptiveDistance = distance * (baseFactor + curvatureFactor * 0.3);

      // 计算切线方向
      Offset previousTangent = Offset(dx / distance, dy / distance);
      if (i > 1) {
        final prevPrevButton = _radioButtons[i - 2];
        final prevDx = previousButton.position.dx - prevPrevButton.position.dx;
        final prevDy = previousButton.position.dy - prevPrevButton.position.dy;
        final prevDistance = sqrt(prevDx * prevDx + prevDy * prevDy);
        if (prevDistance > 0) {
          final prevTangent = Offset(
            prevDx / prevDistance,
            prevDy / prevDistance,
          );
          final currentDirection = Offset(dx / distance, dy / distance);

          final weight = 0.7;
          previousTangent = Offset(
            currentDirection.dx * weight + prevTangent.dx * (1 - weight),
            currentDirection.dy * weight + prevTangent.dy * (1 - weight),
          );

          final tangentLength = sqrt(
            previousTangent.dx * previousTangent.dx +
                previousTangent.dy * previousTangent.dy,
          );
          if (tangentLength > 0) {
            previousTangent = Offset(
              previousTangent.dx / tangentLength,
              previousTangent.dy / tangentLength,
            );
          }
        }
      }

      Offset currentTangent = Offset(dx / distance, dy / distance);
      if (i < _radioButtons.length - 1) {
        final nextButton = _radioButtons[i + 1];
        final nextDx = nextButton.position.dx - currentButton.position.dx;
        final nextDy = nextButton.position.dy - currentButton.position.dy;
        final nextDistance = sqrt(nextDx * nextDx + nextDy * nextDy);
        if (nextDistance > 0) {
          final nextTangent = Offset(
            nextDx / nextDistance,
            nextDy / nextDistance,
          );

          final weight = 0.7;
          currentTangent = Offset(
            currentTangent.dx * weight + nextTangent.dx * (1 - weight),
            currentTangent.dy * weight + nextTangent.dy * (1 - weight),
          );

          final tangentLength = sqrt(
            currentTangent.dx * currentTangent.dx +
                currentTangent.dy * currentTangent.dy,
          );
          if (tangentLength > 0) {
            currentTangent = Offset(
              currentTangent.dx / tangentLength,
              currentTangent.dy / tangentLength,
            );
          }
        }
      }

      // 计算贝塞尔曲线控制点
      final fullControlPoint1 = Offset(
        previousButton.position.dx + previousTangent.dx * adaptiveDistance,
        previousButton.position.dy + previousTangent.dy * adaptiveDistance,
      );
      final fullControlPoint2 = Offset(
        currentButton.position.dx - currentTangent.dx * adaptiveDistance,
        currentButton.position.dy - currentTangent.dy * adaptiveDistance,
      );

      // 使用贝塞尔曲线公式计算精确的结尾位置
      endPosition = _getBezierPointForEndButton(
        previousButton.position,
        fullControlPoint1,
        fullControlPoint2,
        currentButton.position,
        remainingRatio,
      );
    } else {
      // 完整覆盖到某个按钮，使用该按钮的位置
      final endButtonIndex = (coveredButtons - 1).clamp(
        0,
        _radioButtons.length - 1,
      );
      endPosition = _radioButtons[endButtonIndex].position;
    }

    final bigButtonSize = 40.0; // 大按钮尺寸40像素

    return Positioned(
      left: endPosition.dx - bigButtonSize / 2, // 居中定位
      top: endPosition.dy - bigButtonSize / 2, // 居中定位
      child: Container(
        width: bigButtonSize,
        height: bigButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFD700), // 金色填充
          border: Border.all(
            color: Colors.red, // 红色边框
            width: 3.0, // 3像素边框
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.star, // 星星图标表示重要节点
          size: bigButtonSize * 0.6,
          color: Colors.red,
        ),
      ),
    );
  }

  // 构建激活按钮的气泡
  Widget _buildActiveButtonBubble() {
    if (_activeBubbleButtonId == null) return Container();

    // 找到当前激活气泡的按钮
    final activeButton = _radioButtons.firstWhere(
      (btn) => btn.value == _activeBubbleButtonId,
      orElse: () => _radioButtons.first,
    );

    final buttonSize = 30.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = 120.0; // 调整宽度适应5字符换行
    final margin = 8.0;

    // 计算气泡位置
    final buttonLeft = activeButton.position.dx - buttonSize / 2;
    final buttonRight = activeButton.position.dx + buttonSize / 2;
    final rightSpace = screenWidth - buttonRight - margin;

    double bubbleLeft;
    if (rightSpace >= bubbleWidth) {
      // 显示在右侧
      bubbleLeft = buttonRight + margin;
    } else {
      // 显示在左侧
      bubbleLeft = buttonLeft - bubbleWidth - margin;
    }

    // 确保不超出边界
    bubbleLeft = bubbleLeft.clamp(5.0, screenWidth - bubbleWidth - 5.0);

    // 将文本按每行5个字符进行换行
    String formatTextWithLineBreaks(String text) {
      final buffer = StringBuffer();
      for (int i = 0; i < text.length; i += 5) {
        if (i > 0) buffer.write('\n');
        final end = (i + 5 < text.length) ? i + 5 : text.length;
        buffer.write(text.substring(i, end));
      }
      return buffer.toString();
    }

    return Positioned(
      left: bubbleLeft,
      top: activeButton.position.dy - 40, // 调整位置以适应多行文本
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white, // 白色背景
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          formatTextWithLineBreaks("现在的这里已经发生了很大的变化..."),
          style: TextStyle(
            color: Colors.grey[700], // 灰色文字
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.3, // 行高
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  // 构建覆盖层结尾按钮的气泡
  Widget _buildBubbleForEndButton() {
    if (_radioButtons.isEmpty) return Container();

    // 计算覆盖层结尾位置 - 复用大按钮的位置计算逻辑
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 100;
    final coveredButtons = (totalWeight / weightPerButton).floor();
    final remainingWeight = totalWeight % weightPerButton;
    final remainingRatio = remainingWeight / weightPerButton;

    Offset endPosition;
    if (remainingWeight > 0 && coveredButtons < _radioButtons.length - 1) {
      final previousButton = _radioButtons[coveredButtons];
      final currentButton = _radioButtons[coveredButtons + 1];
      endPosition = _getBezierPointForEndButton(
        previousButton.position,
        previousButton.position, // 简化控制点
        currentButton.position, // 简化控制点
        currentButton.position,
        remainingRatio,
      );
    } else {
      final endButtonIndex = (coveredButtons - 1).clamp(
        0,
        _radioButtons.length - 1,
      );
      endPosition = _radioButtons[endButtonIndex].position;
    }

    final bigButtonSize = 40.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = 120.0;
    final margin = 8.0; // 减少边距，让气泡更靠近按钮

    // 计算气泡位置
    final buttonLeft = endPosition.dx - bigButtonSize / 2;
    final buttonRight = endPosition.dx + bigButtonSize / 2;
    final rightSpace = screenWidth - buttonRight - margin;

    double bubbleLeft;
    if (rightSpace >= bubbleWidth) {
      // 显示在右侧
      bubbleLeft = buttonRight + margin;
    } else {
      // 显示在左侧，更靠近按钮
      bubbleLeft = buttonLeft - bubbleWidth - margin;
    }

    // 确保不超出边界，但允许更靠近边缘
    bubbleLeft = bubbleLeft.clamp(5.0, screenWidth - bubbleWidth - 5.0);

    print(
      '气泡位置: 按钮(${endPosition.dx}, ${endPosition.dy}), 气泡($bubbleLeft, ${endPosition.dy - 20})',
    );

    return Positioned(
      left: bubbleLeft,
      top: endPosition.dy - 20, // 按钮中心偏上
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white, // 白色背景
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          "你到这里了",
          style: TextStyle(
            color: Colors.grey[700], // 灰色文字
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 计算大按钮位置的贝塞尔曲线点
  Offset _getBezierPointForEndButton(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    // 三次贝塞尔曲线公式：B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
    final oneMinusT = 1 - t;
    final oneMinusTSquared = oneMinusT * oneMinusT;
    final oneMinusTCubed = oneMinusTSquared * oneMinusT;
    final tSquared = t * t;
    final tCubed = tSquared * t;

    final x =
        oneMinusTCubed * p0.dx +
        3 * oneMinusTSquared * t * p1.dx +
        3 * oneMinusT * tSquared * p2.dx +
        tCubed * p3.dx;

    final y =
        oneMinusTCubed * p0.dy +
        3 * oneMinusTSquared * t * p1.dy +
        3 * oneMinusT * tSquared * p2.dy +
        tCubed * p3.dy;

    return Offset(x, y);
  }
}

class RadioButtonData {
  final String value;
  final Offset position;

  RadioButtonData({required this.value, required this.position});

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'position': {'dx': position.dx, 'dy': position.dy},
    };
  }

  // 从JSON创建
  factory RadioButtonData.fromJson(Map<String, dynamic> json) {
    return RadioButtonData(
      value: json['value'],
      position: Offset(
        json['position']['dx'].toDouble(),
        json['position']['dy'].toDouble(),
      ),
    );
  }
}

class BezierCurvePainter extends CustomPainter {
  final List<RadioButtonData> radioButtons;

  BezierCurvePainter(this.radioButtons);

  @override
  void paint(Canvas canvas, Size size) {
    if (radioButtons.length < 2) return;

    final paint = Paint()
      ..color = Colors.grey
          .withOpacity(0.5) // 50%灰色
      ..strokeWidth =
          20.0 // 调整为20像素
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // 从第一个按钮开始
    final firstButton = radioButtons.first;
    path.moveTo(firstButton.position.dx, firstButton.position.dy);

    // 使用平滑的贝塞尔曲线连接所有按钮
    for (int i = 1; i < radioButtons.length; i++) {
      final currentButton = radioButtons[i];
      final previousButton = radioButtons[i - 1];

      // 计算两点之间的距离和方向
      final dx = currentButton.position.dx - previousButton.position.dx;
      final dy = currentButton.position.dy - previousButton.position.dy;
      final distance = sqrt(dx * dx + dy * dy);

      // 计算曲度（角度变化）来动态调整控制点距离
      double curvature = 0.0;
      if (i > 1 && i < radioButtons.length - 1) {
        final prevPrevButton = radioButtons[i - 2];
        final nextButton = radioButtons[i + 1];

        // 计算前一段和后一段的方向向量
        final prevDirection = Offset(
          previousButton.position.dx - prevPrevButton.position.dx,
          previousButton.position.dy - prevPrevButton.position.dy,
        );
        final nextDirection = Offset(
          nextButton.position.dx - currentButton.position.dx,
          nextButton.position.dy - currentButton.position.dy,
        );

        // 计算两个方向向量的夹角（用点积）
        final prevLength = sqrt(
          prevDirection.dx * prevDirection.dx +
              prevDirection.dy * prevDirection.dy,
        );
        final nextLength = sqrt(
          nextDirection.dx * nextDirection.dx +
              nextDirection.dy * nextDirection.dy,
        );

        if (prevLength > 0 && nextLength > 0) {
          final dotProduct =
              (prevDirection.dx * nextDirection.dx +
                  prevDirection.dy * nextDirection.dy) /
              (prevLength * nextLength);
          // 限制点积值在[-1, 1]范围内，避免数值误差
          final clampedDot = dotProduct.clamp(-1.0, 1.0);
          curvature = acos(clampedDot); // 角度（弧度）
        }
      }

      // 基于曲度动态调整控制点距离
      // 曲度越大，控制点距离越长，让曲线更平滑
      final baseFactor = 0.4;
      final curvatureFactor = curvature / pi; // 归一化到[0,1]
      final adaptiveDistance =
          distance * (baseFactor + curvatureFactor * 0.3); // 0.4-0.7之间

      // 计算前一个点的切线方向，使用平滑算法
      Offset previousTangent = Offset(
        dx / distance,
        dy / distance,
      ); // 使用当前方向作为默认
      if (i > 1) {
        final prevPrevButton = radioButtons[i - 2];
        final prevDx = previousButton.position.dx - prevPrevButton.position.dx;
        final prevDy = previousButton.position.dy - prevPrevButton.position.dy;
        final prevDistance = sqrt(prevDx * prevDx + prevDy * prevDy);
        if (prevDistance > 0) {
          final prevTangent = Offset(
            prevDx / prevDistance,
            prevDy / prevDistance,
          );
          final currentDirection = Offset(dx / distance, dy / distance);

          // 使用加权平均，给当前方向更多权重，减少急转弯
          final weight = 0.7; // 当前方向权重
          previousTangent = Offset(
            currentDirection.dx * weight + prevTangent.dx * (1 - weight),
            currentDirection.dy * weight + prevTangent.dy * (1 - weight),
          );

          // 归一化
          final tangentLength = sqrt(
            previousTangent.dx * previousTangent.dx +
                previousTangent.dy * previousTangent.dy,
          );
          if (tangentLength > 0) {
            previousTangent = Offset(
              previousTangent.dx / tangentLength,
              previousTangent.dy / tangentLength,
            );
          }
        }
      }

      // 计算当前点的切线方向，使用更平滑的算法
      Offset currentTangent = Offset(dx / distance, dy / distance);
      if (i < radioButtons.length - 1) {
        final nextButton = radioButtons[i + 1];
        final nextDx = nextButton.position.dx - currentButton.position.dx;
        final nextDy = nextButton.position.dy - currentButton.position.dy;
        final nextDistance = sqrt(nextDx * nextDx + nextDy * nextDy);
        if (nextDistance > 0) {
          final nextTangent = Offset(
            nextDx / nextDistance,
            nextDy / nextDistance,
          );

          // 使用加权平均，给当前方向更多权重，减少急转弯
          final weight = 0.7; // 当前方向权重
          currentTangent = Offset(
            currentTangent.dx * weight + nextTangent.dx * (1 - weight),
            currentTangent.dy * weight + nextTangent.dy * (1 - weight),
          );

          // 归一化
          final tangentLength = sqrt(
            currentTangent.dx * currentTangent.dx +
                currentTangent.dy * currentTangent.dy,
          );
          if (tangentLength > 0) {
            currentTangent = Offset(
              currentTangent.dx / tangentLength,
              currentTangent.dy / tangentLength,
            );
          }
        }
      }

      // 基于切线方向和自适应距离计算控制点
      final controlPoint1 = Offset(
        previousButton.position.dx + previousTangent.dx * adaptiveDistance,
        previousButton.position.dy + previousTangent.dy * adaptiveDistance,
      );
      final controlPoint2 = Offset(
        currentButton.position.dx - currentTangent.dx * adaptiveDistance,
        currentButton.position.dy - currentTangent.dy * adaptiveDistance,
      );

      // 绘制平滑的贝塞尔曲线
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        currentButton.position.dx,
        currentButton.position.dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  // 计算三次贝塞尔曲线上的点
  Offset _getBezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    // 三次贝塞尔曲线公式：B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
    final oneMinusT = 1 - t;
    final oneMinusTSquared = oneMinusT * oneMinusT;
    final oneMinusTCubed = oneMinusTSquared * oneMinusT;
    final tSquared = t * t;
    final tCubed = tSquared * t;

    final x =
        oneMinusTCubed * p0.dx +
        3 * oneMinusTSquared * t * p1.dx +
        3 * oneMinusT * tSquared * p2.dx +
        tCubed * p3.dx;

    final y =
        oneMinusTCubed * p0.dy +
        3 * oneMinusTSquared * t * p1.dy +
        3 * oneMinusT * tSquared * p2.dy +
        tCubed * p3.dy;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class BezierCurveOverlayPainter extends CustomPainter {
  final List<RadioButtonData> radioButtons;
  final int totalScore; // 添加积分参数

  BezierCurveOverlayPainter(this.radioButtons, this.totalScore);

  @override
  void paint(Canvas canvas, Size size) {
    if (radioButtons.length < 2) return;

    final paint = Paint()
      ..color =
          Color(0xFFFFB6C1) // 淡红色（非透明度）
      ..strokeWidth =
          20.0 // 与原始曲线相同宽度
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // 权重控制参数
    final totalWeight = totalScore; // 使用传入的积分值
    final weightPerButton = 100; // 每个按钮之间的权重
    int remainingWeight = totalWeight; // 剩余权重

    // 从第一个按钮开始绘制
    final firstButton = radioButtons[0];
    path.moveTo(firstButton.position.dx, firstButton.position.dy);

    // 遍历所有按钮，根据权重决定覆盖长度
    for (int i = 1; i < radioButtons.length; i++) {
      // 每经过一个按钮，权重减100
      remainingWeight -= weightPerButton;

      // 如果权重不足，计算等比覆盖
      if (remainingWeight <= 0) {
        // 计算最后一个完整覆盖的按钮
        final lastFullButton = i - 1;
        if (lastFullButton >= 0) {
          final currentButton = radioButtons[i];
          final previousButton = radioButtons[lastFullButton];

          // 计算两点之间的距离和方向
          final dx = currentButton.position.dx - previousButton.position.dx;
          final dy = currentButton.position.dy - previousButton.position.dy;
          final distance = sqrt(dx * dx + dy * dy);

          // 计算剩余权重的比例
          final remainingRatio =
              (remainingWeight + weightPerButton) / weightPerButton;

          // 使用与原始贝塞尔曲线相同的平滑算法
          // 计算曲度（角度变化）来动态调整控制点距离
          double curvature = 0.0;
          if (i > 1 && i < radioButtons.length - 1) {
            final prevPrevButton = radioButtons[i - 2];
            final nextButton = radioButtons[i + 1];

            // 计算前一段和后一段的方向向量
            final prevDirection = Offset(
              previousButton.position.dx - prevPrevButton.position.dx,
              previousButton.position.dy - prevPrevButton.position.dy,
            );
            final nextDirection = Offset(
              nextButton.position.dx - currentButton.position.dx,
              nextButton.position.dy - currentButton.position.dy,
            );

            // 计算两个方向向量的夹角（用点积）
            final prevLength = sqrt(
              prevDirection.dx * prevDirection.dx +
                  prevDirection.dy * prevDirection.dy,
            );
            final nextLength = sqrt(
              nextDirection.dx * nextDirection.dx +
                  nextDirection.dy * nextDirection.dy,
            );

            if (prevLength > 0 && nextLength > 0) {
              final dotProduct =
                  (prevDirection.dx * nextDirection.dx +
                      prevDirection.dy * nextDirection.dy) /
                  (prevLength * nextLength);
              final clampedDot = dotProduct.clamp(-1.0, 1.0);
              curvature = acos(clampedDot);
            }
          }

          // 基于曲度动态调整控制点距离
          final baseFactor = 0.4;
          final curvatureFactor = curvature / pi;
          final adaptiveDistance =
              distance * (baseFactor + curvatureFactor * 0.3);

          // 计算前一个点的切线方向
          Offset previousTangent = Offset(dx / distance, dy / distance);
          if (i > 1) {
            final prevPrevButton = radioButtons[i - 2];
            final prevDx =
                previousButton.position.dx - prevPrevButton.position.dx;
            final prevDy =
                previousButton.position.dy - prevPrevButton.position.dy;
            final prevDistance = sqrt(prevDx * prevDx + prevDy * prevDy);
            if (prevDistance > 0) {
              final prevTangent = Offset(
                prevDx / prevDistance,
                prevDy / prevDistance,
              );
              final currentDirection = Offset(dx / distance, dy / distance);

              final weight = 0.7;
              previousTangent = Offset(
                currentDirection.dx * weight + prevTangent.dx * (1 - weight),
                currentDirection.dy * weight + prevTangent.dy * (1 - weight),
              );

              final tangentLength = sqrt(
                previousTangent.dx * previousTangent.dx +
                    previousTangent.dy * previousTangent.dy,
              );
              if (tangentLength > 0) {
                previousTangent = Offset(
                  previousTangent.dx / tangentLength,
                  previousTangent.dy / tangentLength,
                );
              }
            }
          }

          // 计算当前点的切线方向
          Offset currentTangent = Offset(dx / distance, dy / distance);
          if (i < radioButtons.length - 1) {
            final nextButton = radioButtons[i + 1];
            final nextDx = nextButton.position.dx - currentButton.position.dx;
            final nextDy = nextButton.position.dy - currentButton.position.dy;
            final nextDistance = sqrt(nextDx * nextDx + nextDy * nextDy);
            if (nextDistance > 0) {
              final nextTangent = Offset(
                nextDx / nextDistance,
                nextDy / nextDistance,
              );

              final weight = 0.7;
              currentTangent = Offset(
                currentTangent.dx * weight + nextTangent.dx * (1 - weight),
                currentTangent.dy * weight + nextTangent.dy * (1 - weight),
              );

              final tangentLength = sqrt(
                currentTangent.dx * currentTangent.dx +
                    currentTangent.dy * currentTangent.dy,
              );
              if (tangentLength > 0) {
                currentTangent = Offset(
                  currentTangent.dx / tangentLength,
                  currentTangent.dy / tangentLength,
                );
              }
            }
          }

          // 将贝塞尔曲线划分为100个等分，根据剩余权重精确填充
          final segments = 100; // 100个等分
          final filledSegments = (remainingRatio * segments).floor(); // 需要填充的段数

          // 计算完整的贝塞尔曲线控制点
          final fullControlPoint1 = Offset(
            previousButton.position.dx + previousTangent.dx * adaptiveDistance,
            previousButton.position.dy + previousTangent.dy * adaptiveDistance,
          );
          final fullControlPoint2 = Offset(
            currentButton.position.dx - currentTangent.dx * adaptiveDistance,
            currentButton.position.dy - currentTangent.dy * adaptiveDistance,
          );

          // 逐段绘制贝塞尔曲线
          for (int segment = 0; segment < filledSegments; segment++) {
            final t1 = segment / segments.toDouble(); // 当前段的起始参数
            final t2 = (segment + 1) / segments.toDouble(); // 当前段的结束参数

            // 计算贝塞尔曲线上的点
            final startPoint = _getBezierPoint(
              previousButton.position,
              fullControlPoint1,
              fullControlPoint2,
              currentButton.position,
              t1,
            );
            final endPoint = _getBezierPoint(
              previousButton.position,
              fullControlPoint1,
              fullControlPoint2,
              currentButton.position,
              t2,
            );

            // 绘制线段
            if (segment == 0) {
              path.moveTo(startPoint.dx, startPoint.dy);
            }
            path.lineTo(endPoint.dx, endPoint.dy);
          }

          // 如果还有部分段需要填充，绘制最后一个不完整的段
          final remainingSegmentRatio =
              (remainingRatio * segments) - filledSegments;
          if (remainingSegmentRatio > 0) {
            final t1 = filledSegments / segments.toDouble();
            final t2 = t1 + (remainingSegmentRatio / segments);

            final startPoint = _getBezierPoint(
              previousButton.position,
              fullControlPoint1,
              fullControlPoint2,
              currentButton.position,
              t1,
            );
            final endPoint = _getBezierPoint(
              previousButton.position,
              fullControlPoint1,
              fullControlPoint2,
              currentButton.position,
              t2,
            );

            if (filledSegments == 0) {
              path.moveTo(startPoint.dx, startPoint.dy);
            }
            path.lineTo(endPoint.dx, endPoint.dy);
          }
        }
        break; // 权重用完，结束绘制
      }
      final currentButton = radioButtons[i];
      final previousButton = radioButtons[i - 1];

      // 计算两点之间的距离和方向
      final dx = currentButton.position.dx - previousButton.position.dx;
      final dy = currentButton.position.dy - previousButton.position.dy;
      final distance = sqrt(dx * dx + dy * dy);

      // 计算曲度（角度变化）来动态调整控制点距离
      double curvature = 0.0;
      if (i > 1 && i < radioButtons.length - 1) {
        final prevPrevButton = radioButtons[i - 2];
        final nextButton = radioButtons[i + 1];

        // 计算前一段和后一段的方向向量
        final prevDirection = Offset(
          previousButton.position.dx - prevPrevButton.position.dx,
          previousButton.position.dy - prevPrevButton.position.dy,
        );
        final nextDirection = Offset(
          nextButton.position.dx - currentButton.position.dx,
          nextButton.position.dy - currentButton.position.dy,
        );

        // 计算两个方向向量的夹角（用点积）
        final prevLength = sqrt(
          prevDirection.dx * prevDirection.dx +
              prevDirection.dy * prevDirection.dy,
        );
        final nextLength = sqrt(
          nextDirection.dx * nextDirection.dx +
              nextDirection.dy * nextDirection.dy,
        );

        if (prevLength > 0 && nextLength > 0) {
          final dotProduct =
              (prevDirection.dx * nextDirection.dx +
                  prevDirection.dy * nextDirection.dy) /
              (prevLength * nextLength);
          // 限制点积值在[-1, 1]范围内，避免数值误差
          final clampedDot = dotProduct.clamp(-1.0, 1.0);
          curvature = acos(clampedDot); // 角度（弧度）
        }
      }

      // 基于曲度动态调整控制点距离
      final baseFactor = 0.4;
      final curvatureFactor = curvature / pi; // 归一化到[0,1]
      final adaptiveDistance =
          distance * (baseFactor + curvatureFactor * 0.3); // 0.4-0.7之间

      // 计算前一个点的切线方向，使用平滑算法
      Offset previousTangent = Offset(
        dx / distance,
        dy / distance,
      ); // 使用当前方向作为默认
      if (i > 1) {
        final prevPrevButton = radioButtons[i - 2];
        final prevDx = previousButton.position.dx - prevPrevButton.position.dx;
        final prevDy = previousButton.position.dy - prevPrevButton.position.dy;
        final prevDistance = sqrt(prevDx * prevDx + prevDy * prevDy);
        if (prevDistance > 0) {
          final prevTangent = Offset(
            prevDx / prevDistance,
            prevDy / prevDistance,
          );
          final currentDirection = Offset(dx / distance, dy / distance);

          // 使用加权平均，给当前方向更多权重，减少急转弯
          final weight = 0.7; // 当前方向权重
          previousTangent = Offset(
            currentDirection.dx * weight + prevTangent.dx * (1 - weight),
            currentDirection.dy * weight + prevTangent.dy * (1 - weight),
          );

          // 归一化
          final tangentLength = sqrt(
            previousTangent.dx * previousTangent.dx +
                previousTangent.dy * previousTangent.dy,
          );
          if (tangentLength > 0) {
            previousTangent = Offset(
              previousTangent.dx / tangentLength,
              previousTangent.dy / tangentLength,
            );
          }
        }
      }

      // 计算当前点的切线方向，使用更平滑的算法
      Offset currentTangent = Offset(dx / distance, dy / distance);
      if (i < radioButtons.length - 1) {
        final nextButton = radioButtons[i + 1];
        final nextDx = nextButton.position.dx - currentButton.position.dx;
        final nextDy = nextButton.position.dy - currentButton.position.dy;
        final nextDistance = sqrt(nextDx * nextDx + nextDy * nextDy);
        if (nextDistance > 0) {
          final nextTangent = Offset(
            nextDx / nextDistance,
            nextDy / nextDistance,
          );

          // 使用加权平均，给当前方向更多权重，减少急转弯
          final weight = 0.7; // 当前方向权重
          currentTangent = Offset(
            currentTangent.dx * weight + nextTangent.dx * (1 - weight),
            currentTangent.dy * weight + nextTangent.dy * (1 - weight),
          );

          // 归一化
          final tangentLength = sqrt(
            currentTangent.dx * currentTangent.dx +
                currentTangent.dy * currentTangent.dy,
          );
          if (tangentLength > 0) {
            currentTangent = Offset(
              currentTangent.dx / tangentLength,
              currentTangent.dy / tangentLength,
            );
          }
        }
      }

      // 基于切线方向和自适应距离计算控制点
      final controlPoint1 = Offset(
        previousButton.position.dx + previousTangent.dx * adaptiveDistance,
        previousButton.position.dy + previousTangent.dy * adaptiveDistance,
      );
      final controlPoint2 = Offset(
        currentButton.position.dx - currentTangent.dx * adaptiveDistance,
        currentButton.position.dy - currentTangent.dy * adaptiveDistance,
      );

      // 绘制平滑的贝塞尔曲线
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        currentButton.position.dx,
        currentButton.position.dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  // 计算三次贝塞尔曲线上的点
  Offset _getBezierPoint(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    // 三次贝塞尔曲线公式：B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃
    final oneMinusT = 1 - t;
    final oneMinusTSquared = oneMinusT * oneMinusT;
    final oneMinusTCubed = oneMinusTSquared * oneMinusT;
    final tSquared = t * t;
    final tCubed = tSquared * t;

    final x =
        oneMinusTCubed * p0.dx +
        3 * oneMinusTSquared * t * p1.dx +
        3 * oneMinusT * tSquared * p2.dx +
        tCubed * p3.dx;

    final y =
        oneMinusTCubed * p0.dy +
        3 * oneMinusTSquared * t * p1.dy +
        3 * oneMinusT * tSquared * p2.dy +
        tCubed * p3.dy;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
