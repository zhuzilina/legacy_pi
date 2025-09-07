import 'package:flutter/material.dart';
import 'package:legacy_pi/widgets/floating_action_buttons.dart';
import 'package:legacy_pi/l10n/app_localizations.dart';
import 'package:legacy_pi/widgets/ai_interpretation_dialog.dart';
import 'package:legacy_pi/widgets/key_points_dialog.dart';
import 'package:legacy_pi/pages/chat_page.dart';
import 'package:legacy_pi/models/article.dart';
import 'package:legacy_pi/services/ai_service.dart';
import 'package:legacy_pi/services/unified_cache_service.dart';
import 'package:legacy_pi/main.dart'; // 导入包含 routeObserver 的文件

class KnowledgeDetailPage extends StatefulWidget {
  final Map<String, dynamic> knowledge;

  const KnowledgeDetailPage({
    super.key,
    required this.knowledge,
  });

  @override
  State<KnowledgeDetailPage> createState() => _KnowledgeDetailPageState();
}

class _KnowledgeDetailPageState extends State<KnowledgeDetailPage> with RouteAware {
  late AiService _aiService;
  late UnifiedCacheService _cacheService;
  
  // 悬浮按钮管理器
  FloatingActionButtonsManager? _floatingButtonsManager;

  @override
  void initState() {
    super.initState();
    _aiService = AiService();
    _cacheService = UnifiedCacheService();
    
    // 延迟初始化悬浮按钮，确保在 build 完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFloatingButtons();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅路由观察者
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    // 取消订阅路由观察者
    routeObserver.unsubscribe(this);
    // 销毁悬浮按钮管理器
    _floatingButtonsManager?.dispose();
    super.dispose();
  }
  
  /// 当有新的路由被 push 到当前路由之上时调用
  @override
  void didPushNext() {
    // 当我们离开知识详情页面去往新页面时，隐藏悬浮按钮
    _hideFloatingButtons();
  }

  /// 当顶部的路由被 pop，当前路由重新变为顶部时调用
  @override
  void didPopNext() {
    // 当我们从新页面返回知识详情页面时，显示悬浮按钮
    _showFloatingButtons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.knowledge['title'] ?? '知识详情',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            SelectableText(
              widget.knowledge['title'] ?? '无标题',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            
            // 来源信息
            if (widget.knowledge['source'] != null) ...[
              SelectableText(
                '来源：${widget.knowledge['source']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 内容
            if (widget.knowledge['content'] != null) ...[
              SelectableText(
                widget.knowledge['content'],
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.6,
                  color: Colors.black,
                ),
              ),
            ] else ...[
              const SelectableText(
                '暂无内容',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 初始化悬浮按钮
  void _initializeFloatingButtons() {
    if (_floatingButtonsManager != null) return;
    _showFloatingButtons();
  }
  
  // 显示悬浮按钮
  void _showFloatingButtons() {
    if (_floatingButtonsManager != null) return;
    
    final l10n = AppLocalizations.of(context)!;
    final buttonConfigs = [
      FloatingButtonConfig(
        text: l10n.studyFullText,
        onTap: _onStudyFullText,
      ),
      FloatingButtonConfig(
        text: l10n.summarizeKeyPoints,
        onTap: _onSummarizeKeyPoints,
      ),
      FloatingButtonConfig(
        text: l10n.enterConversation,
        onTap: _onEnterConversation,
      ),
    ];
    
    _floatingButtonsManager = FloatingActionButtonsManager(
      context: context,
      buttonConfigs: buttonConfigs,
      bottomOffset: 187, // 与主页保持一致
      rightOffset: 20,   // 与主页保持一致
    );
    
    _floatingButtonsManager!.show();
  }
  
  // 隐藏悬浮按钮
  void _hideFloatingButtons() {
    _floatingButtonsManager?.dispose();
    _floatingButtonsManager = null;
  }

  /// 学习全文功能
  void _onStudyFullText() {
    // 将知识数据转换为Article对象
    final article = _convertKnowledgeToArticle();
    
    // 隐藏悬浮按钮
    _hideFloatingButtons();
    
    // 显示AI解读对话框
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AiInterpretationDialog(
        article: article,
        aiService: _aiService,
        cacheService: _cacheService,
        promptType: 'summary', // 使用summary提示词类型
      ),
    ).then((_) {
      // 对话框关闭后显示悬浮按钮
      _showFloatingButtons();
    });
  }

  /// 总结要点功能
  void _onSummarizeKeyPoints() {
    // 将知识数据转换为Article对象
    final article = _convertKnowledgeToArticle();
    
    // 隐藏悬浮按钮
    _hideFloatingButtons();
    
    // 显示要点总结对话框
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => KeyPointsDialog(
        article: article,
        aiService: _aiService,
        cacheService: _cacheService,
        promptType: 'key_points', // 使用key_points提示词类型
      ),
    ).then((_) {
      // 对话框关闭后显示悬浮按钮
      _showFloatingButtons();
    });
  }

  /// 进入对话功能
  void _onEnterConversation() {
    // 将知识数据转换为Article对象
    final article = _convertKnowledgeToArticle();
    
    // 导航到聊天页面，消息参数为空
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          article: article,
          messageParam: null, // 消息参数为空
        ),
      ),
    );
  }

  /// 将知识数据转换为Article对象
  Article _convertKnowledgeToArticle() {
    return Article(
      id: widget.knowledge['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: widget.knowledge['title'] ?? '无标题',
      content: widget.knowledge['content'] ?? '暂无内容',
      source: widget.knowledge['source'] ?? '',
      publishTime: widget.knowledge['publishTime'] ?? DateTime.now().toIso8601String(),
      category: widget.knowledge['category'] ?? '知识',
      wordCount: widget.knowledge['wordCount'] ?? 0,
      originalUrl: widget.knowledge['url'] ?? '',
      metaInfo: widget.knowledge['metaInfo'] ?? '',
      collectTime: widget.knowledge['collectTime'] ?? DateTime.now().toIso8601String(),
    );
  }

}
