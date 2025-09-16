import 'package:flutter/material.dart';
import 'package:legacy_pi/pages/ai_preview_page.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user.dart';

import '../services/global_state.dart';
import '../services/button_config_service.dart';
import '../services/journey_state_service.dart';

class JourneyPage extends StatefulWidget {
  final VoidCallback? onScoreUpdated;

  const JourneyPage({super.key, this.onScoreUpdated});

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  final GlobalKey<_ZoomableBackgroundWidgetState> _journeyKey =
      GlobalKey<_ZoomableBackgroundWidgetState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZoomableBackgroundWidget(
        key: _journeyKey,
        onScoreUpdated: () {
          // 当收到积分更新通知时，调用journey页面的检查更新方法
          _journeyKey.currentState?.checkAndUpdateGlobalState();
        },
      ),
    );
  }
}

class ZoomableBackgroundWidget extends StatefulWidget {
  final VoidCallback? onScoreUpdated;

  const ZoomableBackgroundWidget({super.key, this.onScoreUpdated});

  @override
  State<ZoomableBackgroundWidget> createState() =>
      _ZoomableBackgroundWidgetState();
}

class _ZoomableBackgroundWidgetState extends State<ZoomableBackgroundWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 单选按钮数据
  final List<RadioButtonData> _radioButtons = [];
  String? _selectedValue;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 存储键名
  static const String _storageKey = 'journey_button_positions';

  // 气泡状态管理
  int? _activeBubbleButtonId; // 当前显示气泡的按钮ID
  bool _showEndButtonBubble = true; // 控制大按钮气泡的显示

  // 数据库和用户管理
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;
  int _totalScore = 0; // 使用全局状态管理的积分值
  bool _isInitialized = false; // 标记是否已初始化
  bool _hasInitializedFromDatabase = false; // 标记是否已从数据库初始化

  // 按钮配置服务
  final ButtonConfigService _buttonConfigService = ButtonConfigService();

  // 用户头像
  String? _userAvatarPath;

  // 动画控制器
  late AnimationController _buttonAnimationController;
  late AnimationController _overlayAnimationController;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _buttonRotationAnimation;
  late Animation<Color?> _buttonColorAnimation;
  late Animation<Offset> _buttonPositionAnimation;
  late Animation<double> _overlayProgressAnimation;

  // 动画状态
  Offset _previousButtonPosition = Offset.zero;
  Offset _currentButtonPosition = Offset.zero;
  int _previousTotalScore = 0;

  // 粒子动画状态
  List<Particle> _particles = [];
  late AnimationController _particleAnimationController;
  final JourneyStateService _journeyStateService = JourneyStateService();
  Set<int> _activatedButtonIndices = {}; // 记录新激活的按钮索引

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeUserAndDatabase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 当应用重新获得焦点时，检查并更新全局状态
      _checkAndUpdateGlobalState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadButtonConfig();
  }

  // 加载按钮配置
  Future<void> _loadButtonConfig() async {
    try {
      print('开始加载按钮描述配置...');
      await _buttonConfigService.loadConfig();
      print('按钮描述配置加载完成，配置状态: ${_buttonConfigService.isLoaded}');
      
      // 强制重新构建UI以确保配置生效
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('加载按钮描述配置失败: $e');
    }
  }

  // 初始化动画
  void _initializeAnimations() {
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500), // 增加动画时长
      vsync: this,
    );

    _overlayAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500), // 与按钮动画同步
      vsync: this,
    );

    _particleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // 粒子动画时长
      vsync: this,
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _buttonRotationAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _buttonColorAnimation =
        ColorTween(begin: Colors.red[300]!, end: Colors.red[700]!).animate(
          CurvedAnimation(
            parent: _buttonAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // 平移动画将在触发时动态创建
    _buttonPositionAnimation =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
          CurvedAnimation(
            parent: _buttonAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // 覆盖层进度动画将在触发时动态创建
    _overlayProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _overlayAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // 移除图片配置加载方法

  // 移除图片组初始化方法

  // 移除更新激活图片的方法

  // 移除构建背景图片层的方法

  // 移除图片组相关方法

  // 加载用户头像
  Future<void> _loadUserAvatar() async {
    try {
      if (_currentUser != null && _currentUser!.avatarPath != null) {
        setState(() {
          _userAvatarPath = _currentUser!.avatarPath;
        });
        print('从数据库加载用户头像: $_userAvatarPath');
      }
    } catch (e) {
      print('加载用户头像失败: $e');
    }
  }



  // 触发按钮动画
  void _triggerButtonAnimation() {
    print('触发按钮动画，当前积分: $_totalScore，之前积分: $_previousTotalScore');

    // 如果是第一次动画，初始化当前位置
    if (_currentButtonPosition == Offset.zero) {
      _currentButtonPosition = _calculateEndButtonPosition();
      _previousButtonPosition = _currentButtonPosition;
      print('首次动画，初始化按钮位置');
    } else {
      // 保存当前位置作为起始位置
      _previousButtonPosition = _currentButtonPosition;

      // 计算新的目标位置（使用最终积分值）
      _currentButtonPosition = _calculateEndButtonPositionForScore(_totalScore);
      print('非首次动画，从 ${_previousButtonPosition} 移动到 ${_currentButtonPosition}');
    }

    // 创建平移动画
    _buttonPositionAnimation =
        Tween<Offset>(
          begin: _previousButtonPosition,
          end: _currentButtonPosition,
        ).animate(
          CurvedAnimation(
            parent: _buttonAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // 重置并开始动画
    print('重置动画控制器并开始动画');
    _buttonAnimationController.reset();
    _overlayAnimationController.reset();
    _buttonAnimationController.forward();
    _overlayAnimationController.forward();

    // 监听动画完成事件，自动滚动到新位置
    _overlayAnimationController.removeStatusListener(_onAnimationCompleted);
    _overlayAnimationController.addStatusListener(_onAnimationCompleted);
  }

  // 动画完成回调
  void _onAnimationCompleted(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // 动画完成后，延迟滚动到新位置
      Future.delayed(Duration(milliseconds: 300), () {
        _scrollToOverlayEnd();
      });
    }
  }

  // 计算大按钮的目标位置 - 使用与覆盖层完全相同的算法
  Offset _calculateEndButtonPosition() {
    if (_radioButtons.isEmpty) return Offset.zero;

    // 使用动画中的积分值计算位置
    final animatedScore = _overlayAnimationController.isAnimating
        ? _previousTotalScore +
              (_totalScore - _previousTotalScore) *
                  _overlayProgressAnimation.value
        : _totalScore;

    final totalWeight = animatedScore.round();
    final weightPerButton = 500; // 调整权重以适应20个按钮
    int remainingWeight = totalWeight;

    // 从第一个按钮开始
    final firstButton = _radioButtons[0];
    Offset endPosition = firstButton.position;

    // 遍历所有按钮，根据权重决定覆盖长度
    for (int i = 1; i < _radioButtons.length; i++) {
      remainingWeight -= weightPerButton;

      // 检查积分是否为500的整数倍
      if (totalWeight % 500 == 0) {
        // 如果是500的整数倍，直接定位到对应的按钮上
        final buttonIndex = (totalWeight / 500).floor();
        if (buttonIndex < _radioButtons.length) {
          endPosition = _radioButtons[buttonIndex].position;
        } else {
          endPosition = _radioButtons.last.position;
        }
        break;
      }

      // 如果不是500的整数倍，使用覆盖层尾部定位
      if (remainingWeight < 0) {
        // 计算剩余权重的比例
        final remainingRatio =
            (remainingWeight + weightPerButton) / weightPerButton;

        // 使用与覆盖层完全相同的算法计算位置
        final currentButton = _radioButtons[i];
        final previousButton = _radioButtons[i - 1];

        // 计算两点之间的距离和方向
        final dx = currentButton.position.dx - previousButton.position.dx;
        final dy = currentButton.position.dy - previousButton.position.dy;
        final distance = sqrt(dx * dx + dy * dy);

        // 使用与覆盖层相同的贝塞尔曲线算法
        double curvature = 0.0;
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

        // 基于曲度动态调整控制点距离
        final baseFactor = 0.4;
        final curvatureFactor = curvature / pi;
        final adaptiveDistance =
            distance * (baseFactor + curvatureFactor * 0.3);

        // 计算切线方向
        Offset previousTangent = Offset(dx / distance, dy / distance);
        if (i > 1) {
          final prevPrevButton = _radioButtons[i - 2];
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

        // 使用与覆盖层完全相同的分段计算方式
        final segments = 100; // 100个等分
        final filledSegments = (remainingRatio * segments).floor(); // 需要填充的段数

        // 计算最后一个段的结束位置
        final t1 = filledSegments / segments.toDouble();
        final t2 = t1 + (remainingRatio * segments - filledSegments) / segments;

        // 使用与覆盖层完全相同的贝塞尔曲线计算方法
        endPosition = _getBezierPointForEndButton(
          previousButton.position,
          fullControlPoint1,
          fullControlPoint2,
          currentButton.position,
          t2,
        );
        break;
      }
      endPosition = _radioButtons[i].position;
    }

    return endPosition;
  }

  // 根据指定积分值计算大按钮位置
  Offset _calculateEndButtonPositionForScore(int score) {
    if (_radioButtons.isEmpty) return Offset.zero;

    final totalWeight = score;
    final weightPerButton = 500; // 调整权重以适应20个按钮
    int remainingWeight = totalWeight;

    // 检查积分是否为500的整数倍
    if (totalWeight % 500 == 0) {
      // 如果是500的整数倍，直接定位到对应的按钮上
      final buttonIndex = (totalWeight / 500).floor();
      if (buttonIndex < _radioButtons.length) {
        return _radioButtons[buttonIndex].position;
      } else {
        return _radioButtons.last.position;
      }
    }

    // 从第一个按钮开始
    final firstButton = _radioButtons[0];
    Offset endPosition = firstButton.position;

    // 遍历所有按钮，根据权重决定覆盖长度
    for (int i = 1; i < _radioButtons.length; i++) {
      remainingWeight -= weightPerButton;

      // 如果不是500的整数倍，使用覆盖层尾部定位
      if (remainingWeight < 0) {
        // 计算剩余权重的比例
        final remainingRatio =
            (remainingWeight + weightPerButton) / weightPerButton;

        // 使用贝塞尔曲线计算中间位置
        final currentButton = _radioButtons[i];
        final previousButton = _radioButtons[i - 1];

        // 计算两点之间的距离和方向
        final dx = currentButton.position.dx - previousButton.position.dx;
        final dy = currentButton.position.dy - previousButton.position.dy;
        final distance = sqrt(dx * dx + dy * dy);

        // 使用与覆盖层相同的贝塞尔曲线算法
        double curvature = 0.0;
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

        // 基于曲度动态调整控制点距离
        final baseFactor = 0.4;
        final curvatureFactor = curvature / pi;
        final adaptiveDistance =
            distance * (baseFactor + curvatureFactor * 0.3);

        // 计算切线方向
        Offset previousTangent = Offset(dx / distance, dy / distance);
        if (i > 1) {
          final prevPrevButton = _radioButtons[i - 2];
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

        // 使用与覆盖层完全相同的分段计算方式
        final segments = 100; // 100个等分
        final filledSegments = (remainingRatio * segments).floor(); // 需要填充的段数

        // 计算最后一个段的结束位置
        final t1 = filledSegments / segments.toDouble();
        final t2 = t1 + (remainingRatio * segments - filledSegments) / segments;

        // 使用与覆盖层完全相同的贝塞尔曲线计算方法
        endPosition = _getBezierPointForEndButton(
          previousButton.position,
          fullControlPoint1,
          fullControlPoint2,
          currentButton.position,
          t2,
        );
        break;
      }
      endPosition = _radioButtons[i].position;
    }

    return endPosition;
  }

  @override
  void dispose() {
    // 移除积分监听器
    GlobalState().removeScoreListener(_onScoreChanged);

    // 移除应用生命周期观察者
    WidgetsBinding.instance.removeObserver(this);

    _scrollController.dispose();
    _buttonAnimationController.dispose();
    _overlayAnimationController.dispose();
    _particleAnimationController.dispose();
    super.dispose();
  }

  // 初始化用户和数据库
  Future<void> _initializeUserAndDatabase() async {
    try {
      // 从全局状态获取用户和积分
      final globalState = GlobalState();
      _currentUser = globalState.currentUser;
      _totalScore = globalState.globalScore;

      // 添加积分监听器
      globalState.addScoreListener(_onScoreChanged);

      // 加载用户头像
      await _loadUserAvatar();

      // 加载按钮位置
      _loadOrGenerateButtonPositions();

      _isInitialized = true;
    } catch (e) {
      print('初始化失败: $e');
      // 如果初始化失败，使用默认值
      _totalScore = 120;
      _loadOrGenerateButtonPositions();
      _isInitialized = true;
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
        
        // 检查保存的按钮数量，如果不是20个就重新生成
        if (savedPositions.length != 20) {
          print('检测到保存的按钮数量为${savedPositions.length}，不是20个，将重新生成');
          _generateRandomRadioButtons();
          return;
        }
        
        _radioButtons.clear();

        for (int i = 0; i < savedPositions.length; i++) {
          final positionData = savedPositions[i];
          final button = RadioButtonData.fromJson(positionData);

          // 如果按钮ID为0（说明是旧数据），重新分配ID
          if (button.id == 0) {
            print('检测到旧数据按钮，重新分配ID: ${i + 1}');
            _radioButtons.add(
              RadioButtonData(
                id: i + 1,
                value: button.value,
                position: button.position,
              ),
            );
          } else {
            _radioButtons.add(button);
          }
        }

        setState(() {});

        // 延迟初始化大按钮位置和滚动到覆盖层结尾处
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // 初始化大按钮位置和动画状态
          _currentButtonPosition = _calculateEndButtonPosition();
          _previousButtonPosition = _currentButtonPosition;
          _previousTotalScore = _totalScore;

          // 初始化已激活按钮集合
          _activatedButtonIndices.clear();
          _journeyStateService.clearActivatedButtons();
          final totalWeight = _totalScore;
          final weightPerButton = 500; // 调整权重以适应20个按钮
          final coveredButtons = (totalWeight / weightPerButton).floor();
          final remainingWeight = totalWeight % weightPerButton;

          for (int i = 0; i < _radioButtons.length; i++) {
            final isInOverlay =
                i < coveredButtons ||
                (i == coveredButtons && remainingWeight >= 0);
            if (isInOverlay) {
              _activatedButtonIndices.add(i);
              _journeyStateService.addActivatedButton(i);
            }
          }

          // 移除图片组管理器初始化

          // 强制重新构建以显示覆盖层
          setState(() {});

          // 滚动到覆盖层结尾处，等待滚动完成后再更新全局状态
          print('开始滚动到覆盖层结尾处...');
          await _scrollToOverlayEnd();
          print('滚动完成，等待2秒后更新全局状态...');

          // 等待2秒，让用户看到滚动完成的效果
          print('等待1秒，让用户观察滚动完成的效果...');
          await Future.delayed(Duration(seconds: 1));
          print('等待完成，开始更新全局状态...');

          // 页面初始化完成并滚动定位后，更新全局状态为数据库最新值
          if (_isInitialized && !_hasInitializedFromDatabase) {
            // 仅在页面首次初始化时更新，避免重复触发
            _updateGlobalStateFromDatabase();
            _hasInitializedFromDatabase = true;
          }
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

    // 获取屏幕尺寸 - 使用响应式尺寸
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 使用 MediaQuery 获取当前屏幕尺寸，确保与响应式布局一致
      final size = MediaQuery.of(context).size;

      // 计算可用宽度（屏幕宽度减去左右边距）
      final margin = size.width * 0.25; // 使用固定的边距比例
      final availableWidth = size.width - (margin * 2); // 可用宽度
      final startX = margin; // 左边距

      // 生成20个按钮，沿Y轴等距分布，X轴随机
      for (int i = 0; i < 20; i++) {
        // Y轴等距分布，使用配置的间距
        // 从容器底部开始，向上分布
        final yPosition =
            (size.height + 7000) - // 使用调整后的容器高度
            50 - // 使用固定的按钮边距
            (i * 300); // 使用300像素间距

        // X轴随机分布
        final xPosition = startX + (random.nextDouble() * availableWidth);

        _radioButtons.add(
          RadioButtonData(
            id: i + 1, // 使用索引+1作为ID
            value: '选项${i + 1}', // 使用简单的选项名称
            position: Offset(xPosition, yPosition),
          ),
        );

        // 调试第一个按钮的位置
        if (i == 0) {
          print(
            '第一个按钮位置: ID=${i + 1}, 位置=(${xPosition.toStringAsFixed(2)}, ${yPosition.toStringAsFixed(2)})',
          );
          print('屏幕尺寸: ${size.width} x ${size.height}');
          print('容器高度: 7000');
        }
      }

      // 保存新生成的位置
      _saveButtonPositions();

      setState(() {}); // 重新构建UI

      // 延迟初始化大按钮位置和滚动到覆盖层结尾处，确保布局完成
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // 初始化大按钮位置和动画状态
        _currentButtonPosition = _calculateEndButtonPosition();
        _previousButtonPosition = _currentButtonPosition;
        _previousTotalScore = _totalScore;

        // 初始化已激活按钮集合
        _activatedButtonIndices.clear();
        _journeyStateService.clearActivatedButtons();
        final totalWeight = _totalScore;
        final weightPerButton = 500; // 调整权重以适应20个按钮
        final coveredButtons = (totalWeight / weightPerButton).floor();
        final remainingWeight = totalWeight % weightPerButton;

        for (int i = 0; i < _radioButtons.length; i++) {
          final isInOverlay =
              i < coveredButtons ||
              (i == coveredButtons && remainingWeight >= 0);
          if (isInOverlay) {
            _activatedButtonIndices.add(i);
            _journeyStateService.addActivatedButton(i);
          }
        }

        // 移除图片组管理器初始化2

        // 强制重新构建以显示覆盖层
        setState(() {});

        // 滚动到覆盖层结尾处，等待滚动完成后再更新全局状态
        print('开始滚动到覆盖层结尾处...');
        await _scrollToOverlayEnd();
        print('滚动完成，等待2秒后更新全局状态...');

        // 等待2秒，让用户看到滚动完成的效果
        print('等待2秒，让用户观察滚动完成的效果...');
        await Future.delayed(Duration(seconds: 2));
        print('等待完成，开始更新全局状态...');

        // 页面初始化完成并滚动定位后，更新全局状态为数据库最新值
        if (_isInitialized && !_hasInitializedFromDatabase) {
          // 仅在页面首次初始化时更新，避免重复触发
          _updateGlobalStateFromDatabase();
          _hasInitializedFromDatabase = true;
        }
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
  Future<void> _scrollToOverlayEnd() async {
    if (!_scrollController.hasClients || _radioButtons.isEmpty) return;

    // 计算覆盖层结尾位置，使用与覆盖层结尾大按钮相同的算法
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 500; // 调整权重以适应20个按钮
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
      final endButtonIndex = coveredButtons.clamp(0, _radioButtons.length - 1);
      endPosition = _radioButtons[endButtonIndex].position;
    }

    // 计算滚动位置（减去屏幕高度的一半，让覆盖层结尾在屏幕中央）
    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset = endPosition.dy - screenHeight / 2;

    // 确保滚动位置在有效范围内
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final clampedOffset = scrollOffset.clamp(0.0, maxScrollExtent);

    // 执行滚动动画并等待完成
    await _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }



  // 滚动到大按钮位置
  Future<void> _scrollToEndButton() async {
    if (!_scrollController.hasClients || _radioButtons.isEmpty) return;

    // 计算大按钮的位置
    final endPosition = _calculateEndButtonPosition();
    
    // 计算滚动位置（让大按钮在屏幕中央）
    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset = endPosition.dy - screenHeight / 2;

    // 确保滚动位置在有效范围内
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final clampedOffset = scrollOffset.clamp(0.0, maxScrollExtent);

    // 执行滚动动画
    await _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // 获取响应式尺寸
                final screenWidth = constraints.maxWidth;
                final screenHeight = constraints.maxHeight;
                final containerHeight = 7000; // 调整容器高度以适应20个按钮
                final bottomPadding = 220.0; // 减少底部垫高到220像素
                final totalHeight =
                    screenHeight + containerHeight + bottomPadding;

                return SingleChildScrollView(
                  controller: _scrollController,
                  child: SizedBox(
                    width: screenWidth,
                    height: totalHeight,
                    child: Stack(
                      children: [
                        // 贝塞尔曲线连接线 - 添加IgnorePointer确保不拦截点击事件
                        IgnorePointer(
                          child: CustomPaint(
                            size: Size(screenWidth, totalHeight),
                            painter: BezierCurvePainter(_radioButtons),
                          ),
                        ),
                        // 贝塞尔曲线覆盖层 - 添加IgnorePointer确保不拦截点击事件
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _overlayAnimationController,
                            builder: (context, child) {
                              // 计算动画中的积分值
                              final animatedScore =
                                  _overlayAnimationController.isAnimating
                                  ? _previousTotalScore +
                                        (_totalScore - _previousTotalScore) *
                                            _overlayProgressAnimation.value
                                  : _totalScore;

                              return CustomPaint(
                                size: Size(screenWidth, totalHeight),
                                painter: BezierCurveOverlayPainter(
                                  _radioButtons,
                                  animatedScore.round(),
                                ),
                              );
                            },
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
                        // 粒子效果 - 添加IgnorePointer确保不拦截点击事件
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _particleAnimationController,
                            builder: (context, child) {
                              // 更新粒子
                              _updateParticles(0.016); // 约60fps

                              return CustomPaint(
                                size: Size(screenWidth, totalHeight),
                                painter: ParticlePainter(_particles),
                              );
                            },
                          ),
                        ),
                        // 底部垫高容器，确保第一个按钮不被遮挡
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: screenWidth,
                            height: bottomPadding,
                            color: Colors.transparent, // 透明背景
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // 积分显示 - 右上角
            Positioned(
              top: 50, // 距离顶部50像素
              right: 20, // 距离右边20像素
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent, // 透明背景
                ),
                child: Text(
                  '积分: $_totalScore',
                  style: TextStyle(
                    color: Colors.red[700], // 主题红色
                    fontSize: 20, // 增大字体到20像素
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // 悬浮图片 - 水平靠右，垂直居中
            Positioned(
              right: 20, // 水平靠右
              top: 0, // 将在LayoutBuilder中计算垂直居中位置
              bottom: 0, // 将在LayoutBuilder中计算垂直居中位置
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Image.asset(
                        'assets/images/person.png',
                        width: 80, // 增大图片宽度
                        height: 122, // 按原比例计算高度 (1008/1536 ≈ 0.656, 80/0.656 ≈ 122)
                        fit: BoxFit.contain, // 保持原比例显示
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey[400],
                          );
                        },
                      ),
                    ),
                    onTap: () {
                      // 导航到 AR 页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ARWebviewPage()),
                      );
                    },
                  );
                },
              ),
            ),
            // 浮动定位按钮
            Positioned(
              bottom: 30,
              right: 20,
              child: FloatingActionButton(
                onPressed: _scrollToEndButton,
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                child: const Icon(Icons.my_location),
                tooltip: '定位到当前进度',
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildRadioButton(RadioButtonData radioData) {
    final buttonSize = 30.0; // 调整为30像素

    // 计算按钮索引
    final buttonIndex = _radioButtons.indexOf(radioData);

    // 计算覆盖层是否经过此按钮
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 500; // 调整权重以适应20个按钮
    final coveredButtons = (totalWeight / weightPerButton).floor();
    final remainingWeight = totalWeight % weightPerButton;
    final isInOverlay =
        buttonIndex < coveredButtons ||
        (buttonIndex == coveredButtons && remainingWeight >= 0);

    // 判断按钮是否激活：用户手动选择或覆盖层经过
    final isActive = _selectedValue == radioData.value || isInOverlay;
    
    // 调试信息：只打印前几个按钮的状态
    if (buttonIndex < 5) {
      print('按钮状态调试: ID=${radioData.id}, Index=$buttonIndex, isInOverlay=$isInOverlay, isActive=$isActive, totalScore=$_totalScore');
      print('按钮位置: (${radioData.position.dx.toStringAsFixed(1)}, ${radioData.position.dy.toStringAsFixed(1)})');
    }

    return Positioned(
      left: radioData.position.dx - buttonSize / 2, // 居中定位
      top: radioData.position.dy - buttonSize / 2, // 居中定位
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive
              ? () {
                  print('按钮被点击: ID=${radioData.id}, Value=${radioData.value}, isActive=$isActive');
                  setState(() {
                    _selectedValue = radioData.value;
                    // 切换气泡显示状态
                    if (_activeBubbleButtonId == radioData.id) {
                      print('隐藏气泡: 按钮ID=${radioData.id}');
                      _activeBubbleButtonId = null; // 如果已经显示，则隐藏
                    } else {
                      print('显示气泡: 按钮ID=${radioData.id}');
                      _activeBubbleButtonId = radioData.id; // 否则显示气泡
                    }
                    print('当前激活气泡按钮ID: $_activeBubbleButtonId');
                  });
                }
              : null, // 未激活时禁用点击事件
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.red[50] // 激活时淡红色填充
                  : Colors.white, // 未激活时白色填充
              border: Border.all(
                color: isActive
                    ? Colors.red // 激活时红色边框
                    : Colors.grey.withOpacity(0.5), // 未激活时50%灰色边框
                width: isActive ? 3.0 : 2.0, // 激活时更粗的边框以便识别
              ),
              // 添加阴影让按钮更明显
              boxShadow: isActive ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 6.0,
                  spreadRadius: 1.0,
                ),
              ] : null,
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
    final weightPerButton = 500; // 调整权重以适应20个按钮
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
      final endButtonIndex = coveredButtons.clamp(0, _radioButtons.length - 1);
      endPosition = _radioButtons[endButtonIndex].position;
    }

    final bigButtonSize = 40.0; // 大按钮尺寸40像素

    return AnimatedBuilder(
      animation: Listenable.merge([
        _buttonAnimationController,
        _overlayAnimationController,
      ]),
      builder: (context, child) {
        // 始终使用与覆盖层相同的积分值计算位置，确保完全同步
        final currentPosition = _calculateEndButtonPosition();

        return Positioned(
          left: currentPosition.dx - bigButtonSize / 2,
          top: currentPosition.dy - bigButtonSize / 2,
          child: GestureDetector(
            onTap: () {
              // 检查大按钮是否与小按钮重叠
              final overlappingButton = _findOverlappingButton(endPosition);
              if (overlappingButton != null) {
                // 如果重叠，隐藏大按钮气泡，显示小按钮气泡
                setState(() {
                  _showEndButtonBubble = false;
                  _activeBubbleButtonId = overlappingButton.id;
                });
              } else {
                // 如果没有重叠，切换大按钮气泡显示状态
                setState(() {
                  _showEndButtonBubble = !_showEndButtonBubble;
                  _activeBubbleButtonId = null;
                });
              }
            },
            child: Container(
              width: bigButtonSize,
              height: bigButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _userAvatarPath != null
                    ? Colors.transparent
                    : _buttonColorAnimation.value, // 使用动画颜色
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
              child: _userAvatarPath != null
                  ? ClipOval(
                      child: Image.file(
                        File(_userAvatarPath!),
                        width: bigButtonSize,
                        height: bigButtonSize,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.star, // 星星图标表示重要节点
                      size: bigButtonSize * 0.6,
                      color: Colors.red,
                    ),
            ),
          ),
        );
      },
    );
  }

  // 构建激活按钮的气泡
  Widget _buildActiveButtonBubble() {
    print('构建激活按钮气泡: _activeBubbleButtonId=$_activeBubbleButtonId');
    if (_activeBubbleButtonId == null) {
      print('没有激活的气泡按钮，返回空容器');
      return Container();
    }

    // 找到当前激活气泡的按钮
    final activeButton = _radioButtons.firstWhere(
      (btn) => btn.id == _activeBubbleButtonId,
      orElse: () => _radioButtons.first,
    );
    print('找到激活按钮: ID=${activeButton.id}');

    // 检查配置服务状态
    print('配置服务是否已加载: ${_buttonConfigService.isLoaded}');

    // 获取按钮的描述文本
    final buttonDescription = _buttonConfigService.getDescriptionById(activeButton.id);
    if (buttonDescription == null) {
      print('未找到按钮 ${activeButton.id} 的描述，不显示气泡');
      return Container();
    }
    print('找到按钮描述: ${buttonDescription.title} - ${buttonDescription.description}');

    final buttonSize = 30.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = 200.0; // 增加宽度以适应更长的文本
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

    return Positioned(
      left: bubbleLeft,
      top: activeButton.position.dy - 60, // 调整位置以适应更多文本
      child: Container(
        width: bubbleWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 主要内容
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 40, 12), // 右侧留出关闭按钮空间
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    buttonDescription.title,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  // 描述
                  Text(
                    buttonDescription.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    print('气泡关闭按钮被点击');
                    setState(() {
                      _activeBubbleButtonId = null;
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建覆盖层结尾按钮的气泡
  Widget _buildBubbleForEndButton() {
    if (_radioButtons.isEmpty || !_showEndButtonBubble) return Container();

    // 计算覆盖层结尾位置 - 复用大按钮的位置计算逻辑
    final totalWeight = _totalScore; // 使用数据库中的积分值
    final weightPerButton = 500; // 调整权重以适应20个按钮
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
      final endButtonIndex = coveredButtons.clamp(0, _radioButtons.length - 1);
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
        child: Stack(
          children: [
            // 主要内容
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 40, 10), // 右侧留出关闭按钮空间
              child: Text(
                "你到这里了",
                style: TextStyle(
                  color: Colors.grey[700], // 灰色文字
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    print('大按钮气泡关闭按钮被点击');
                    setState(() {
                      _showEndButtonBubble = false;
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 查找与大按钮重叠的小按钮
  RadioButtonData? _findOverlappingButton(Offset endPosition) {
    final bigButtonSize = 40.0;
    final smallButtonSize = 30.0;

    for (final button in _radioButtons) {
      // 计算两个按钮中心点之间的距离
      final distance = sqrt(
        pow(endPosition.dx - button.position.dx, 2) +
            pow(endPosition.dy - button.position.dy, 2),
      );

      // 如果距离小于两个按钮半径之和，则认为重叠
      if (distance < (bigButtonSize + smallButtonSize) / 2) {
        return button;
      }
    }
    return null;
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

  // 创建粒子效果
  void _createParticleEffect(Offset position) {
    print('创建粒子效果，位置: $position');
    final random = Random();
    final particleCount = 120; // 大幅增加粒子数量到120个

    // 定义彩色粒子颜色数组
    final colors = [
      Colors.red[400]!, // 红色
      Color(0xFFFF6B35), // 橙色
      Color(0xFFFF1493), // 深粉色
      Color(0xFF00CED1), // 深青色
      Color(0xFF32CD32), // 酸橙绿
      Color(0xFF9370DB), // 中等紫色
      Color(0xFFFF4500), // 橙红色
      Color(0xFF00BFFF), // 深天蓝
      Color(0xFFFF69B4), // 热粉色
      Color(0xFF7CFC00), // 草坪绿
      Color(0xFFFFF700), // 柠檬黄
      Color(0xFF8A2BE2), // 蓝紫色
      Color(0xFFFF6347), // 番茄色
      Color(0xFF00FA9A), // 春绿色
    ];

    // 一次性创建所有粒子，立即显示
    for (int i = 0; i < particleCount; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 100 + random.nextDouble() * 200; // 100-300的速度，更快的初始速度
      final velocity = Offset(cos(angle) * speed, sin(angle) * speed);

      // 随机选择颜色
      final color = colors[random.nextInt(colors.length)];

      // 创建更细腻的粒子大小分布
      final size = i < particleCount * 0.1
          ? 6 +
                random.nextDouble() *
                    10 // 10%的大粒子
          : i < particleCount * 0.3
          ? 3 +
                random.nextDouble() *
                    6 // 20%的中等粒子
          : 1 + random.nextDouble() * 3; // 70%的小粒子

      final particle = Particle(
        position: position,
        velocity: velocity,
        life: 1.0 + random.nextDouble() * 0.8, // 1.0-1.8秒的生命，稍微缩短
        maxLife: 1.0 + random.nextDouble() * 0.8,
        color: color,
        size: size,
      );

      _particles.add(particle);
    }

    // 立即开始粒子动画，所有粒子同时出现
    _particleAnimationController.reset();
    _particleAnimationController.forward();
    print('粒子效果创建完成，粒子数量: $particleCount');
  }

  // 更新粒子
  void _updateParticles(double deltaTime) {
    _particles.removeWhere((particle) {
      particle.update(deltaTime);
      return particle.isDead();
    });
  }

  // 检测新激活的按钮
  void _detectNewlyActivatedButtons() {
    final totalWeight = _totalScore;
    final weightPerButton = 500; // 调整权重以适应20个按钮
    final coveredButtons = (totalWeight / weightPerButton).floor();
    final remainingWeight = totalWeight % weightPerButton;

    final newlyActivated = <int>{};

    for (int i = 0; i < _radioButtons.length; i++) {
      final isInOverlay =
          i < coveredButtons || (i == coveredButtons && remainingWeight >= 0);

      if (isInOverlay && !_activatedButtonIndices.contains(i)) {
        newlyActivated.add(i);
      }
    }

    if (newlyActivated.isNotEmpty) {
      print('检测到 ${newlyActivated.length} 个新激活的按钮: $newlyActivated');

      // 为新激活的按钮创建粒子效果
      for (final buttonIndex in newlyActivated) {
        if (buttonIndex < _radioButtons.length) {
          print('为按钮 $buttonIndex 创建粒子效果');
          _createParticleEffect(_radioButtons[buttonIndex].position);
        }
      }
    } else {
      print('没有检测到新激活的按钮');
    }

    // 更新已激活按钮集合
    _activatedButtonIndices.addAll(newlyActivated);
    _journeyStateService.updateActivatedButtons(_activatedButtonIndices);

    // 移除图片组相关逻辑
  }

  // 积分变化监听器
  void _onScoreChanged(int newScore) {
    if (mounted) {
      print('积分监听器触发，新积分: $newScore，当前积分: $_totalScore');

      // 检查是否是特殊标记，用于触发数据库检查
      if (newScore == -1) {
        print('收到特殊标记，触发数据库检查更新');
        checkAndUpdateGlobalState();
        return;
      }

      // 如果还在初始化阶段，跳过更新
      if (!_hasInitializedFromDatabase) {
        print('页面还在初始化阶段，跳过积分监听器更新');
        return;
      }

      // 检查积分值是否有实际变化
      if (newScore != _totalScore) {
        print('检测到积分值变化，准备触发动画');

        // 保存之前的积分值
        _previousTotalScore = _totalScore;

        setState(() {
          _totalScore = newScore;
        });

        print('页面积分已更新为: $_totalScore');

        // 触发动画效果
        _triggerButtonAnimation();

        // 检测新激活的按钮并创建粒子效果
        _detectNewlyActivatedButtons();
      } else {
        print('积分值无变化，仅更新显示');
        setState(() {
          _totalScore = newScore;
        });
      }
    }
  }

  // 从数据库更新全局状态（仅在页面初始化完成时调用）
  Future<void> _updateGlobalStateFromDatabase() async {
    try {
      print('开始从数据库更新全局状态（初始化阶段）...');
      // 从数据库读取最新积分值
      if (_currentUser != null) {
        final latestScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );
        print('从数据库读取到最新积分值: $latestScore');

        // 检查积分值是否有变化
        if (latestScore != _totalScore) {
          print('检测到积分值变化: $_totalScore -> $latestScore，准备触发动画');

          // 保存之前的积分值用于动画
          _previousTotalScore = _totalScore;

          // 更新页面状态
          setState(() {
            _totalScore = latestScore;
          });

          // 更新全局状态
          final globalState = GlobalState();
          globalState.setScoreSilently(latestScore);

          // 触发动画效果
          _triggerButtonAnimation();

          // 检测新激活的按钮并创建粒子效果
          _detectNewlyActivatedButtons();

          print('页面初始化完成，已更新全局状态为数据库最新值: $latestScore，并触发动画和粒子效果');
        } else {
          print('积分值无变化，仅更新全局状态');
          // 更新全局状态
          final globalState = GlobalState();
          globalState.setScoreSilently(latestScore);
        }
      }
    } catch (e) {
      print('更新全局状态失败: $e');
    }
  }

  // 检查并更新全局状态（用于页面重新获得焦点时）
  Future<void> _checkAndUpdateGlobalState() async {
    try {
      print('页面重新获得焦点，检查并更新全局状态...');

      // 如果还在初始化阶段，跳过更新
      if (!_hasInitializedFromDatabase) {
        print('页面还在初始化阶段，跳过积分更新检查');
        return;
      }

      if (_currentUser != null) {
        // 从数据库读取最新积分值
        final latestScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );
        print('从数据库读取到最新积分值: $latestScore，当前页面积分: $_totalScore');

        // 检查积分值是否有变化
        if (latestScore != _totalScore) {
          print('检测到积分值变化: $_totalScore -> $latestScore，准备触发动画和粒子效果');

          // 保存之前的积分值用于动画
          _previousTotalScore = _totalScore;

          // 更新页面状态
          setState(() {
            _totalScore = latestScore;
          });

          // 更新全局状态
          final globalState = GlobalState();
          globalState.setScoreSilently(latestScore);

          // 触发动画效果
          _triggerButtonAnimation();

          // 检测新激活的按钮并创建粒子效果
          _detectNewlyActivatedButtons();

          print('页面重新获得焦点后，已更新积分为: $latestScore，并触发动画和粒子效果');
        } else {
          print('积分值无变化，无需更新');
        }
      }
    } catch (e) {
      print('检查并更新全局状态失败: $e');
    }
  }

  // 检查并更新全局状态（用于抽屉页面积分更新后）
  Future<void> checkAndUpdateGlobalState() async {
    try {
      print('收到积分更新通知，检查并更新全局状态...');

      // 如果还在初始化阶段，跳过更新
      if (!_hasInitializedFromDatabase) {
        print('页面还在初始化阶段，跳过积分更新检查');
        return;
      }

      if (_currentUser != null) {
        // 从数据库读取最新积分值
        final latestScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );
        print('从数据库读取到最新积分值: $latestScore，当前页面积分: $_totalScore');

        // 检查积分值是否有变化
        if (latestScore != _totalScore) {
          print('检测到积分值变化: $_totalScore -> $latestScore，准备触发动画和粒子效果');

          // 保存之前的积分值用于动画
          _previousTotalScore = _totalScore;

          // 更新页面状态
          setState(() {
            _totalScore = latestScore;
          });

          // 更新全局状态
          final globalState = GlobalState();
          globalState.setScoreSilently(latestScore);

          // 触发动画效果
          _triggerButtonAnimation();

          // 检测新激活的按钮并创建粒子效果
          _detectNewlyActivatedButtons();

          print('抽屉页面积分更新后，已更新积分为: $latestScore，并触发动画和粒子效果');
        } else {
          print('积分值无变化，无需更新');
        }
      }
    } catch (e) {
      print('检查并更新全局状态失败: $e');
    }
  }
}

class RadioButtonData {
  final int id;
  final String value;
  final Offset position;

  RadioButtonData({
    required this.id,
    required this.value,
    required this.position,
  });

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'position': {'dx': position.dx, 'dy': position.dy},
    };
  }

  // 从JSON创建
  factory RadioButtonData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? 0;
    print('从JSON加载按钮: ID=$id, 原始JSON=$json');
    return RadioButtonData(
      id: id,
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
    final weightPerButton = 500; // 调整权重以适应20个按钮 // 每个按钮之间的权重
    int remainingWeight = totalWeight; // 剩余权重

    // 从第一个按钮开始绘制
    final firstButton = radioButtons[0];
    path.moveTo(firstButton.position.dx, firstButton.position.dy);

    // 遍历所有按钮，根据权重决定覆盖长度
    for (int i = 1; i < radioButtons.length; i++) {
      // 每经过一个按钮，权重减500
      remainingWeight -= weightPerButton;

      // 如果权重不足，计算等比覆盖
      if (remainingWeight < 0) {
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

// 粒子类
class Particle {
  Offset position;
  Offset velocity;
  double life;
  double maxLife;
  Color color;
  double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.maxLife,
    required this.color,
    required this.size,
  });

  void update(double deltaTime) {
    position += velocity * deltaTime;
    velocity *= 0.92; // 更强的阻力，让粒子更快减速并聚集
    life -= deltaTime;
  }

  bool isDead() => life <= 0;
}

// 粒子绘制器
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final opacity = (particle.life / particle.maxLife).clamp(0.0, 1.0);

      // 绘制发光效果（更细腻）
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 0.8);

      canvas.drawCircle(particle.position, particle.size * 2.0, glowPaint);

      // 绘制主粒子
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particle.position, particle.size, paint);

      // 绘制高光效果（更细腻）
      if (particle.size > 2) {
        // 只为较大的粒子添加高光
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(opacity * 0.7)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(
            particle.position.dx - particle.size * 0.25,
            particle.position.dy - particle.size * 0.25,
          ),
          particle.size * 0.25,
          highlightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
