import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/user_score.dart';
import '../models/chat_record.dart';
import '../services/chat_record_service.dart';
import '../models/article.dart';
import '../pages/chat_page.dart';
import '../services/journey_state_service.dart';
import '../pages/reward_page.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final int points;
  final bool isCompleted;
  final bool canClaim;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.isCompleted,
    required this.canClaim,
  });
}

class ProfileDrawer extends StatefulWidget {
  final VoidCallback? onScoreUpdated;
  final VoidCallback? onDrawerClosed;

  const ProfileDrawer({super.key, this.onScoreUpdated, this.onDrawerClosed});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer>
    with WidgetsBindingObserver {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;
  int _totalScore = 0;
  int _achievementsCount = 0;
  final ImagePicker _picker = ImagePicker();
  bool _hasScoreUpdated = false;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _initializeTasks();
    _loadUserData();
    WidgetsBinding.instance.addObserver(this);
  }

  // 初始化任务列表
  void _initializeTasks() {
    final journeyStateService = JourneyStateService();

    // 检查全局任务状态，如果没有则初始化
    if (journeyStateService.taskStates.isEmpty) {
      final initialStates = {
        'login': TaskState(isCompleted: false, canClaim: true),
        'read_5min': TaskState(isCompleted: false, canClaim: true),
        'study_5min': TaskState(isCompleted: false, canClaim: false),
        'daily_quiz': TaskState(isCompleted: false, canClaim: false),
      };
      journeyStateService.initializeTaskStates(initialStates);
    }

    // 从全局状态获取任务状态
    final taskStates = journeyStateService.taskStates;

    _tasks = [
      Task(
        id: 'login',
        title: '登录APP',
        description: '每日登录应用程序',
        points: 20,
        isCompleted: taskStates['login']?.isCompleted ?? false,
        canClaim: taskStates['login']?.canClaim ?? false,
      ),
      Task(
        id: 'read_5min',
        title: '阅读5分钟',
        description: '累计阅读时长达到5分钟',
        points: 50,
        isCompleted: taskStates['read_5min']?.isCompleted ?? false,
        canClaim: taskStates['read_5min']?.canClaim ?? false,
      ),
      Task(
        id: 'study_5min',
        title: '学习5分钟',
        description: '累计学习时长达到5分钟',
        points: 50,
        isCompleted: taskStates['study_5min']?.isCompleted ?? false,
        canClaim: taskStates['study_5min']?.canClaim ?? false,
      ),
      Task(
        id: 'daily_quiz',
        title: '参与每日一答',
        description: '完成每日答题挑战',
        points: 50,
        isCompleted: taskStates['daily_quiz']?.isCompleted ?? false,
        canClaim: taskStates['daily_quiz']?.canClaim ?? false,
      ),
    ];
  }

  // 领取任务奖励
  Future<void> _claimTaskReward(Task task) async {
    if (!task.canClaim || task.isCompleted) return;

    try {
      // 添加积分记录
      await _databaseHelper.insertUserScore(
        UserScore(
          userId: _currentUser!.id!,
          score: task.points,
          description: '完成任务: ${task.title}',
          earnedAt: DateTime.now(),
        ),
      );

      // 更新全局任务状态
      final journeyStateService = JourneyStateService();
      journeyStateService.updateTaskState(
        task.id,
        TaskState(isCompleted: true, canClaim: false),
      );

      // 更新本地任务状态
      setState(() {
        final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
        if (taskIndex != -1) {
          _tasks[taskIndex] = Task(
            id: task.id,
            title: task.title,
            description: task.description,
            points: task.points,
            isCompleted: true,
            canClaim: false,
          );
        }
      });

      // 重新加载用户数据
      await _loadUserData();
    } catch (e) {
      // 静默处理错误，不显示提示消息
    }
  }

  // 获取已激活的按钮数量（成就数量）
  Future<int> _getActivatedButtonsCount() async {
    try {
      // 使用 JourneyStateService 获取激活的按钮数量
      final journeyStateService = JourneyStateService();
      return journeyStateService.activatedButtonsCount;
    } catch (e) {
      print('获取激活按钮数量失败: $e');
      return 0;
    }
  }

  Future<void> _loadUserData() async {
    try {
      // 获取默认用户
      _currentUser = await _databaseHelper.getUserByUsername('default_user');

      if (_currentUser != null) {
        // 加载积分数据
        _totalScore = await _databaseHelper.getTotalUserScore(
          _currentUser!.id!,
        );

        // 加载成就数据（从 JourneyPage 的激活按钮获取）
        _achievementsCount = await _getActivatedButtonsCount();

        setState(() {});
      }
    } catch (e) {
      print('加载用户数据失败: $e');
    }
  }

  // 刷新聊天记录
  void _refreshChatRecords() {
    setState(() {});
  }
  
  // 构建任务项
  Widget _buildTaskItem(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // 任务信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${task.points}积分',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // 领取按钮
          if (task.canClaim && !task.isCompleted)
            ElevatedButton(
              onPressed: () => _claimTaskReward(task),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                elevation: 0,
                minimumSize: const Size(50, 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                '领取',
                style: TextStyle(fontSize: 11),
              ),
            )
          else if (task.isCompleted)
            const Text(
              '已领取',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              '未完成',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  // 格式化时间
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
  
  // 继续对话
  void _continueChat(ChatRecord record) {
    // 创建Article对象
    final article = Article(
      id: record.chatKey,
      title: record.title,
      source: '学习记录',
      publishTime: record.lastUpdated.toIso8601String(),
      category: '学习记录',
      wordCount: record.content.length,
      originalUrl: '',
      metaInfo: '学习记录',
      content: record.content,
      collectTime: record.lastUpdated.toIso8601String(),
    );
    
    // 导航到聊天页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(article: article),
      ),
    );
  }
  
  // 删除聊天记录
  Future<void> _deleteChatRecord(ChatRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${record.title}"的学习记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await ChatRecordService.deleteChatRecord(record.title);
      setState(() {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除"${record.title}"的学习记录')),
        );
      }
    }
  }

  // 选择头像
  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null && _currentUser != null) {
        // 更新用户头像路径
        final updatedUser = _currentUser!.copyWith(
          avatarPath: image.path,
          updatedAt: DateTime.now(),
        );

        await _databaseHelper.updateUser(updatedUser);
        _currentUser = updatedUser;
        setState(() {});
      }
    } catch (e) {
      print('选择头像失败: $e');
    }
  }

  // 编辑昵称
  Future<void> _editNickname() async {
    if (_currentUser == null) return;

    final TextEditingController controller = TextEditingController(
      text: _currentUser!.nickname ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '昵称', hintText: '请输入昵称'),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final updatedUser = _currentUser!.copyWith(
        nickname: result.trim(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateUser(updatedUser);
      _currentUser = updatedUser;
      setState(() {});
    }
  }

  // 编辑个人简介
  Future<void> _editBio() async {
    if (_currentUser == null) return;

    final TextEditingController controller = TextEditingController(
      text: _currentUser!.bio ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑个人简介'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '个人简介',
            hintText: '请输入个人简介',
          ),
          maxLines: 3,
          maxLength: 100,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedUser = _currentUser!.copyWith(
        bio: result.trim(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateUser(updatedUser);
      _currentUser = updatedUser;
      setState(() {});
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
        child: Column(
          children: [
            // 用户信息头部
            _buildUserHeader(),

            // 积分和成就
            _buildPointsAndAchievements(),

            // 学习记录
            _buildLearningRecords(),

            // 设置选项
            _buildSettings(),

            // 底部信息
            _buildFooter(),
          ],
        ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('ProfileDrawer: didChangeDependencies 被调用');
    // 监听抽屉关闭事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('ProfileDrawer: 添加抽屉关闭监听器');
        // 检查抽屉是否即将关闭
        final route = ModalRoute.of(context);
        if (route != null) {
          print('ProfileDrawer: 找到路由，添加WillPopCallback');
          route.addScopedWillPopCallback(() async {
            print(
              'ProfileDrawer: WillPopCallback 被触发，当前标记状态: $_hasScoreUpdated',
            );
            // 抽屉即将关闭时，检查是否需要通知积分更新
            if (_hasScoreUpdated) {
              print('ProfileDrawer: 抽屉即将关闭，通知积分更新');
              // 延迟执行，确保抽屉完全关闭后再通知
              Future.delayed(const Duration(milliseconds: 300), () {
                print('ProfileDrawer: 延迟执行通知回调');
                widget.onDrawerClosed?.call();
                _hasScoreUpdated = false;
              });
            } else {
              print('ProfileDrawer: 没有积分更新标记，不通知');
            }
            return true;
          });
        } else {
          print('ProfileDrawer: 未找到路由');
        }
      } else {
        print('ProfileDrawer: 组件未挂载');
      }
    });
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red[700]!, Colors.red[500]!],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 用户头像 - 可点击选择
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: _currentUser?.avatarPath != null
                        ? FileImage(File(_currentUser!.avatarPath!))
                        : null,
                    child: _currentUser?.avatarPath == null
                        ? Icon(Icons.person, size: 40, color: Colors.red[700])
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 用户昵称 - 可点击编辑
            GestureDetector(
              onTap: _editNickname,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentUser?.nickname ?? '红色文化学习者',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 个人简介 - 可点击编辑
            if (_currentUser?.bio != null && _currentUser!.bio!.isNotEmpty)
              GestureDetector(
                onTap: _editBio,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    _currentUser!.bio!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // 用户等级
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Lv.5 红色传承者',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsAndAchievements() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '积分与成就',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 积分卡片
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.stars,
                      color: Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前积分',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '$_totalScore',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RewardPage(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_giftcard,
                          color: Colors.red[600],
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '兑换',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 成就卡片
          GestureDetector(
            onTap: () async {
              await _loadUserData();
            },
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '获得成就',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '$_achievementsCount 个',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.refresh, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 任务列表卡片
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.task_alt,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '每日任务',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 任务列表
                  ..._tasks.map((task) => _buildTaskItem(task)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningRecords() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '学习记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _refreshChatRecords,
                child: const Text('刷新', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FutureBuilder<List<ChatRecord>>(
            future: ChatRecordService.getAllChatRecords(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return const Center(child: Text('加载失败'));
              }
              
              final chatRecords = snapshot.data ?? [];
              
              if (chatRecords.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Text(
                      '暂无学习记录',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              
              return Column(
                children: chatRecords.map((record) => _buildChatRecordItem(record)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatRecordItem(ChatRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.chat, color: Colors.blue, size: 20),
        ),
        title: Text(
          record.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${record.messageCount}条对话 · ${_formatTime(record.lastUpdated)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) {
            if (value == 'continue') {
              _continueChat(record);
            } else if (value == 'delete') {
              _deleteChatRecord(record);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'continue',
              child: Row(
                children: [
                  Icon(Icons.chat, size: 16),
                  SizedBox(width: 8),
                  Text('继续对话'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16),
                  SizedBox(width: 8),
                  Text('删除记录'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _continueChat(record),
      ),
    );
  }

  Widget _buildSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildSettingItem(
            icon: Icons.info,
            title: '关于我们',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[600], size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '红色文化学习 v1.0.0',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '让红色文化在新时代焕发新光彩',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 在dispose时检查是否需要通知积分更新
    if (_hasScoreUpdated) {
      print('ProfileDrawer: 组件销毁时，通知积分更新');
      widget.onDrawerClosed?.call();
      _hasScoreUpdated = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用失去焦点时（抽屉关闭），检查是否需要通知积分更新
    if (state == AppLifecycleState.paused && _hasScoreUpdated) {
      print('ProfileDrawer: 应用失去焦点，检查是否需要通知积分更新');
      // 延迟执行，确保抽屉完全关闭
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_hasScoreUpdated) {
          print('ProfileDrawer: 抽屉关闭，通知积分更新');
          widget.onDrawerClosed?.call();
          _hasScoreUpdated = false;
        }
      });
    }
  }
}
