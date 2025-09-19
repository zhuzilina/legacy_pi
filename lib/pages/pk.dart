import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:legacy_pi/pages/question.dart';
import 'package:legacy_pi/services/global_state.dart';
import 'package:legacy_pi/models/user.dart';
import 'package:legacy_pi/database/database_helper.dart';

class PKPage extends StatefulWidget {
  const PKPage({super.key});

  @override
  State<PKPage> createState() => _PKState();
}

class _PKState extends State<PKPage> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  bool _matched = false;
  bool _isLoading = false;
  Timer? _matchingTimer;
  late AnimationController _titleController;
  late Animation<double> _titleAnimation;

  // 用户相关
  User? _currentUser;
  String? _userAvatarPath;
  static const String _opponentName = '努力的大明'; // 对手昵称
  static const String _opponentAvatar = 'assets/images/avatar1.png'; // 对手头像

  @override
  void initState() {
    super.initState();
    // 初始化标题动画控制器
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _titleAnimation = Tween(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );

    // 初始化用户和头像
    _initializeUserAndAvatar();

    // 开始匹配计时器
    _startMatching();
  }

  // 构建跳动的点
  Widget _buildJumpingDot(int index) {
    return AnimatedBuilder(
      animation: _titleController,
      builder: (context, child) {
        // 根据索引和动画进度计算偏移量
        final progress = _titleController.value;
        final jumpOffset = math.sin(progress * math.pi * 2 + index * math.pi / 3) * 10;

        return Transform.translate(
          offset: Offset(0, -jumpOffset.abs()),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.red[700],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
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

  void _startMatching() {
    _matchingTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        _progress += 0.2;
        if (_progress >= 1.0) {
          timer.cancel();
          _matchSuccess();
        }
      });
    });
  }

  void _matchSuccess() {
    setState(() {
      _matched = true;
      _titleController.stop();
    });
  }

  void _startPK() {
    setState(() {
      _isLoading = true;
    });

    // 模拟加载过程
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => DailyQuizPage(title: '123')),
        );
      }
    });
  }

  Future<void> _cancelMatching() async {
    if (_isLoading) return;

    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('取消匹配'),
            content: const Text('确定要取消匹配吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && mounted) {
      _matchingTimer?.cancel();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _matchingTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 禁用屏幕旋转
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('答题PK')),
      body: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                AnimatedBuilder(
                  animation: _titleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _matched ? 1.1 : _titleAnimation.value,
                      child: Text(
                        _matched ? "匹配成功！" : "正在寻找对手🔥",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // 头像区域
                SizedBox(
                  width: double.infinity,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 用户头像
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 40, // 为昵称留出空间
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withValues(alpha: 0.8),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.grey[300],
                                child: _userAvatarPath != null
                                    ? ClipOval(
                                        child: Image.file(
                                          File(_userAvatarPath!),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 40,
                                              color: Colors.grey[600],
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.grey[600],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 用户昵称
                            Text(
                              _currentUser?.nickname ?? _currentUser?.username ?? '我',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // VS文字（中间）
                      const Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),

                      // 加载动画 - 三个点跳动（在VS下方）
                      if (!_matched) ...[
                        Positioned(
                          bottom: 10,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildJumpingDot(0),
                              const SizedBox(width: 4),
                              _buildJumpingDot(1),
                              const SizedBox(width: 4),
                              _buildJumpingDot(2),
                            ],
                          ),
                        ),
                      ],

                      // 对手头像
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 500),
                        right: _matched ? 0 : -MediaQuery.of(context).size.width / 4,
                        top: 0,
                        bottom: 40, // 为昵称留出空间
                        child: Transform.scale(
                          scale: _matched ? 1.0 : 0.5,
                          child: Opacity(
                            opacity: _matched ? 1.0 : 0.0,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                                  child: CircleAvatar(
                                    radius: 45,
                                    backgroundImage: AssetImage(_opponentAvatar),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 对手昵称
                                Text(
                                  _opponentName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
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
                const SizedBox(height: 48),

                // 匹配成功提示
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _matched ? 1.0 : 0.0,
                  child: Transform.translate(
                    offset: Offset(0, _matched ? 0 : 20),
                    child: const Text(
                      '   匹配成功！',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 加载状态或按钮
                if (_isLoading) ...[
                  const Column(
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(strokeWidth: 4),
                      ),
                      SizedBox(height: 16),
                      Text('加载中...', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ] else ...[
                  InkWell(
                    onTap: _matched ? _startPK : _cancelMatching,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 48,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      child: Text(
                        _matched ? '开始PK' : '取消匹配',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}