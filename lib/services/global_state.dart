import 'dart:async';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/user_score.dart';

class GlobalState {
  static final GlobalState _instance = GlobalState._internal();
  factory GlobalState() => _instance;
  GlobalState._internal();

  // 全局积分状态
  int _globalScore = 0;
  User? _currentUser;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // 监听器列表
  final List<Function(int)> _scoreListeners = [];

  // 获取当前积分
  int get globalScore => _globalScore;

  // 获取当前用户
  User? get currentUser => _currentUser;

  // 初始化全局状态（在App启动时调用）
  Future<void> initialize() async {
    try {
      // 初始化数据库
      await _databaseHelper.database;

      // 获取默认用户
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
        _globalScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );
      }

      print('全局状态初始化完成，当前积分: $_globalScore');
    } catch (e) {
      print('全局状态初始化失败: $e');
      // 如果初始化失败，使用默认值
      _globalScore = 120;
    }
  }

  // 更新积分（从数据库读取最新值）
  Future<void> updateScoreFromDatabase() async {
    try {
      if (_currentUser != null) {
        final newScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );
        if (newScore != _globalScore) {
          _globalScore = newScore;
          _notifyScoreListeners();
          print('全局积分已更新: $_globalScore');
        }
      }
    } catch (e) {
      print('从数据库更新积分失败: $e');
    }
  }

  // 添加积分监听器
  void addScoreListener(Function(int) listener) {
    _scoreListeners.add(listener);
  }

  // 移除积分监听器
  void removeScoreListener(Function(int) listener) {
    _scoreListeners.remove(listener);
  }

  // 通知所有监听器
  void _notifyScoreListeners() {
    for (final listener in _scoreListeners) {
      listener(_globalScore);
    }
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // 直接设置积分值（不触发监听器，用于页面初始化）
  void setScoreSilently(int score) {
    _globalScore = score;
  }

  // 手动触发监听器通知（用于页面初始化后通知UI更新）
  void notifyScoreListeners() {
    print('手动触发积分监听器通知，当前积分: $_globalScore，监听器数量: ${_scoreListeners.length}');
    _notifyScoreListeners();
  }

  // 通知所有监听器检查数据库更新（用于抽屉页面积分更新后）
  void notifyCheckDatabaseUpdate() {
    print('通知所有监听器检查数据库更新，监听器数量: ${_scoreListeners.length}');
    for (final listener in _scoreListeners) {
      // 传递一个特殊值来触发检查更新
      listener(-1); // 使用-1作为特殊标记
    }
  }

  // 重置全局状态（用于测试）
  void reset() {
    _globalScore = 0;
    _currentUser = null;
    _scoreListeners.clear();
  }
}
