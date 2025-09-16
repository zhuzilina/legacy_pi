import 'package:flutter/material.dart';
import '../models/chat_record.dart';
import '../services/chat_record_service.dart';
import '../models/article.dart';
import '../pages/chat_page.dart';

class RecentLearningPage extends StatefulWidget {
  const RecentLearningPage({super.key});

  @override
  State<RecentLearningPage> createState() => _RecentLearningPageState();
}

class _RecentLearningPageState extends State<RecentLearningPage> {
  List<ChatRecord> _chatRecords = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChatRecords();
  }

  Future<void> _loadChatRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await ChatRecordService.getAllChatRecords();
      setState(() {
        _chatRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载学习记录失败: $e';
        _isLoading = false;
      });
    }
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ChatRecordService.deleteChatRecord(record.title);
      _loadChatRecords(); // 重新加载列表

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除"${record.title}"的学习记录')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('最近学习'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadChatRecords,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChatRecords,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_chatRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无学习记录',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '开始学习后将在这里显示记录',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chatRecords.length,
        itemBuilder: (context, index) {
          final record = _chatRecords[index];
          return _buildChatRecordCard(record);
        },
      ),
    );
  }

  Widget _buildChatRecordCard(ChatRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _continueChat(record),
        borderRadius: BorderRadius.circular(12),
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.chat,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.messageCount}条对话 · ${_formatTime(record.lastUpdated)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
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
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('删除记录', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (record.content.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  record.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}