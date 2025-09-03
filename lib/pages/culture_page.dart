import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/news_api_service.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/unified_cache_service.dart';
import '../services/markdown_parser_service.dart';
import '../models/article.dart';
import '../widgets/rich_content_widget.dart';

class CulturePage extends StatefulWidget {
  const CulturePage({super.key});

  @override
  State<CulturePage> createState() => _CulturePageState();
}

class _CulturePageState extends State<CulturePage> with TickerProviderStateMixin {
  final UnifiedCacheService _cacheService = UnifiedCacheService();
  late TabController _tabController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
     // API 服务
   final NewsApiService _newsApiService = NewsApiService();
   final AiService _aiService = AiService();
   
   // 分类数据
   final List<String> _categories = ['新闻', '精神', '人物', '党史'];
   int _currentTabIndex = 0;
  
  // 各分类的数据状态
  final Map<String, bool> _isLoadingMap = {};
  final Map<String, String> _errorMessageMap = {};
  final Map<String, List<Article>> _articlesMap = {};
  
  // 浮动按钮状态
  bool _showFloatingOptions = false;
  
  // 统一配色方案：白底黑字
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    
    // 初始化各分类的状态
    for (final category in _categories) {
      _isLoadingMap[category] = false;
      _errorMessageMap[category] = '';
      _articlesMap[category] = [];
    }
    
    // 加载默认分类（新闻）的数据
    _loadArticlesForCategory(_categories[0]);
    
    // 监听Tab切换
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final newIndex = _tabController.index;
      setState(() {
        _currentTabIndex = newIndex;
        _currentPage = 0; // 重置页面索引
      });
      
      // 如果该分类还没有数据，则加载
      final category = _categories[newIndex];
      if (_articlesMap[category]!.isEmpty && !_isLoadingMap[category]!) {
        _loadArticlesForCategory(category);
      }
    }
  }

  // 加载指定分类的文章数据
  Future<void> _loadArticlesForCategory(String category) async {
    setState(() {
      _isLoadingMap[category] = true;
      _errorMessageMap[category] = '';
    });

    try {
      print('开始加载 $category 分类的文章数据...');
      
      // 目前只有"新闻"分类有真实API，其他分类使用模拟数据
      if (category == '新闻') {
        await _loadNewsArticles(category);
      } else {
        await _loadMockArticles(category);
      }
      
    } catch (e) {
      print('加载 $category 文章时发生错误: $e');
      setState(() {
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = '加载文章时发生错误: $e';
      });
    }
  }

  // 加载新闻分类的真实数据
  Future<void> _loadNewsArticles(String category) async {
    final articleListResponse = await _newsApiService.getDailyArticles();
    
    if (articleListResponse == null) {
      setState(() {
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = '无法连接到服务器';
      });
      return;
    }

    if (articleListResponse.msg == 'crawling_started') {
      setState(() {
        _isLoadingMap[category] = true;
        _errorMessageMap[category] = '正在爬取最新文章，请稍后...';
      });
      
      // 30秒后重试
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          _loadArticlesForCategory(category);
        }
      });
      return;
    }

    if (articleListResponse.msg != 'success') {
      setState(() {
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = articleListResponse.error ?? '获取文章列表失败';
      });
      return;
    }

    // 批量获取文章内容（全部，并发）
    final articles = await _newsApiService.getMultipleArticles(
      articleListResponse.articleIds,
      maxCount: null, // 获取全部
      concurrency: 6, // 控制并发数
    );

    if (articles.isEmpty) {
      setState(() {
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = '暂无可用文章内容';
      });
      return;
    }

    setState(() {
      _articlesMap[category] = articles;
      _isLoadingMap[category] = false;
      _errorMessageMap[category] = '';
    });

    print('$category 文章加载完成，共 ${articles.length} 篇');
  }

  // 加载模拟数据（用于精神、人物、党史分类）
  Future<void> _loadMockArticles(String category) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(seconds: 1));
    
    final mockArticles = _generateMockArticles(category);
    
    setState(() {
      _articlesMap[category] = mockArticles;
      _isLoadingMap[category] = false;
      _errorMessageMap[category] = '';
    });

    print('$category 模拟文章加载完成，共 ${mockArticles.length} 篇');
  }

  // 生成模拟文章数据
  List<Article> _generateMockArticles(String category) {
    final mockData = {
      '精神': [
        {'title': '弘扬伟大建党精神', 'content': '中国共产党在长期奋斗中形成的伟大建党精神，是党的宝贵精神财富...'},
        {'title': '传承红色基因', 'content': '红色基因是中国共产党人的精神内核，是激励我们不断前行的强大力量...'},
        {'title': '践行初心使命', 'content': '为中国人民谋幸福，为中华民族谋复兴，是中国共产党人的初心和使命...'},
      ],
      '人物': [
        {'title': '革命先烈的光辉事迹', 'content': '无数革命先烈为了民族独立和人民解放，献出了宝贵的生命...'},
        {'title': '时代楷模的感人故事', 'content': '在新时代的征程中，涌现出许多可歌可泣的时代楷模...'},
        {'title': '英雄模范的崇高品格', 'content': '英雄模范人物以其崇高的品格和无私的奉献，诠释了共产党人的初心...'},
      ],
      '党史': [
        {'title': '中国共产党的光辉历程', 'content': '中国共产党自1921年成立以来，走过了波澜壮阔的百年历程...'},
        {'title': '重大历史事件回顾', 'content': '在党的历史上，有许多具有重大意义的历史事件和重要节点...'},
        {'title': '历史经验和启示', 'content': '党的百年历史为我们提供了丰富的历史经验和深刻的启示...'},
      ],
    };

    final data = mockData[category] ?? [];
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final publishDate = DateTime.now().subtract(Duration(days: index));
      return Article(
        id: '${category}_mock_$index',
        title: item['title']!,
        source: '学习强国',
        publishTime: publishDate.toString().split(' ')[0],
        category: category,
        wordCount: 1000 + index * 200,
        originalUrl: 'https://example.com/${category}_$index',
        metaInfo: '来源：学习强国\n发布时间：${publishDate.toString().split(' ')[0]}',
        content: item['content']! * 5, // 重复内容以模拟长文章
        collectTime: DateTime.now().toString(),
      );
    }).toList();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 0, // 减少AppBar高度
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48), // 设置TabBar高度
          child: TabBar(
            controller: _tabController,
            tabs: _categories.map((category) => Tab(
              text: category,
            )).toList(),
            labelColor: _textColor,
            unselectedLabelColor: _textColor.withOpacity(0.6),
            indicatorColor: _textColor,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: _categories.map((category) => _buildCategoryView(category)).toList(),
          ),
                                // 浮动按钮和选项
            Positioned(
              bottom: 60, // 距离底部60像素，避免与TabBar重叠
              right: 20, // 距离右边20像素
              child: _buildFloatingButtonWithOptions(),
            ),
        ],
      ),
    );
  }

  // 构建分类视图
  Widget _buildCategoryView(String category) {
    final isLoading = _isLoadingMap[category] ?? false;
    final errorMessage = _errorMessageMap[category] ?? '';
    final articles = _articlesMap[category] ?? [];

    // 主要内容
    if (isLoading) {
      return _buildLoadingView(category);
    } else if (errorMessage.isNotEmpty) {
      return _buildErrorView(category);
    } else if (articles.isEmpty) {
      return _buildEmptyView(category);
    } else {
      return _buildArticlePageView(articles);
    }
  }

  // 加载状态视图
  Widget _buildLoadingView(String category) {
    final errorMessage = _errorMessageMap[category] ?? '';
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _backgroundColor,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_textColor),
              ),
              const SizedBox(height: 20),
              Text(
                errorMessage.isNotEmpty ? errorMessage : '正在加载$category内容...',
                style: TextStyle(
                  fontSize: 16,
                  color: _textColor.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 错误状态视图
  Widget _buildErrorView(String category) {
    final errorMessage = _errorMessageMap[category] ?? '';
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 20),
                Text(
                  '加载失败',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 16,
                    color: _textColor.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _loadArticlesForCategory(category),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _textColor,
                    foregroundColor: _backgroundColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 空状态视图
  Widget _buildEmptyView(String category) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: _textColor.withOpacity(0.4),
                ),
                const SizedBox(height: 20),
                Text(
                  '暂无$category内容',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '当前没有可显示的$category内容',
                  style: TextStyle(
                    fontSize: 16,
                    color: _textColor.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _loadArticlesForCategory(category),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('刷新'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 文章页面视图
  Widget _buildArticlePageView(List<Article> articles) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (int page) {
        setState(() {
          _currentPage = page;
        });
      },
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        
        return Stack(
          children: [
            // 主要内容区域
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: _backgroundColor,
              ),
              child: SafeArea(
      child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 100.0), // 底部留出空间给覆盖层
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      // 正文内容（富文本，不可滚动，固定高度）
                      Expanded(
                        child: Stack(
              children: [
                            // 内容区域
                            ClipRect(
                              child: RichContentWidget(
                                contentItems: article.parseContentItems(),
                                textStyle: TextStyle(
                                  fontSize: 24, // 增大字体到24
                                  height: 1.6,
                                  color: _textColor,
                                  fontWeight: FontWeight.w400,
                                ),
                                textColor: _textColor,
                                enableScrolling: false, // 禁用滚动
                              ),
                            ),
                            // 渐变遮罩和查看更多按钮
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 80,
                  decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _backgroundColor.withOpacity(0.0),
                                      _backgroundColor.withOpacity(0.7),
                                      _backgroundColor.withOpacity(0.95),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showFullContentDialog(article),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _textColor,
                                      foregroundColor: _backgroundColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    icon: const Icon(Icons.expand_more, size: 20),
                                    label: const Text(
                                      '查看更多',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                                             // 滑动提示已移除
                const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            // 底部简化覆盖层
            _buildSimplifiedBottomOverlay(article),
          ],
        );
      },
    );
  }
  

  
  // 简化的底部覆盖层（只显示标题和来源）
  Widget _buildSimplifiedBottomOverlay(Article article) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundColor.withOpacity(0.0),
              _backgroundColor.withOpacity(0.85),
              _backgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文章标题（大号字体）
                Text(
                  article.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    height: 1.2,
                  ),
                  maxLines: 2, // 最多显示2行
                  overflow: TextOverflow.ellipsis, // 超出省略
                ),
                const SizedBox(height: 8),
                // 来源信息（小号字体）
                Text(
                  '来源: ${article.source}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textColor.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

           // 显示全文内容对话框
     void _showFullContentDialog(Article article) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (BuildContext context) {
           return TweenAnimationBuilder<double>(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOutBack,
             tween: Tween(begin: 0.0, end: 1.0),
             builder: (context, scale, child) {
               return Transform.scale(
                 scale: scale,
                 child: _FullContentDialog(
                   article: article,
                 ),
               );
             },
           );
         },
       );
     }
     
     // 显示AI解读对话框
     void _showAiInterpretationDialog(Article article, {String promptType = 'summary'}) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (BuildContext context) {
           return TweenAnimationBuilder<double>(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOutBack,
             tween: Tween(begin: 0.0, end: 1.0),
             builder: (context, scale, child) {
               return Transform.scale(
                 scale: scale,
                 child: _AiInterpretationDialog(
                   article: article,
                   aiService: _aiService,
                   cacheService: _cacheService,
                   promptType: promptType,
                 ),
               );
             },
           );
         },
       );
     }
     
     // 显示总结要点对话框（内容撑开高度）
     void _showKeyPointsDialog(Article article) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (BuildContext context) {
           return TweenAnimationBuilder<double>(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOutBack,
             tween: Tween(begin: 0.0, end: 1.0),
             builder: (context, scale, child) {
               return Transform.scale(
                 scale: scale,
                 child: _KeyPointsDialog(
                   article: article,
                   aiService: _aiService,
                   cacheService: _cacheService,
                   promptType: 'key_points',
                 ),
               );
             },
           );
         },
       );
     }

  // 页面指示器
  Widget _buildPageIndicator(int totalCount) {
    return Positioned(
      right: 20,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            totalCount,
            (index) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: 8,
              height: _currentPage == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? _textColor
                    : _textColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

     // 构建三个垂直排列的悬浮按钮
   Widget _buildFloatingButtonWithOptions() {
     return SizedBox(
       width: 120, // 减小容器宽度
       height: MediaQuery.of(context).size.height / 3, // 屏幕高度的三分之一
       child: Column(
         mainAxisAlignment: MainAxisAlignment.end, // 从底部开始排列
         crossAxisAlignment: CrossAxisAlignment.end,
         children: [
           // 学习全文按钮
           _buildNewFloatingButton('学习\n全文', 0),
           const SizedBox(height: 8),
           // 总结要点按钮
           _buildNewFloatingButton('总结\n要点', 1),
           const SizedBox(height: 8),
           // 进入对话按钮
           _buildNewFloatingButton('进入\n对话', 2),
                 ],
      ),
    );
  }
  


  // 构建新的圆形悬浮按钮
          Widget _buildNewFloatingButton(String text, int index) {
          return Container(
            width: 40,
            height: 40,
      decoration: BoxDecoration(
        color: Colors.red[700], // 主题色背景（红色）
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
                   child: InkWell(
             borderRadius: BorderRadius.circular(40),
             onTap: () {
               print('悬浮按钮被点击: $text');
               // 获取当前显示的文章
               final currentArticle = _articlesMap[_categories[_currentTabIndex]]?[_currentPage];
               if (currentArticle != null) {
                 // 为第一个按钮（学习全文）添加AI解读功能
                 if (index == 0) {
                   _showAiInterpretationDialog(currentArticle);
                 }
                 // 为第二个按钮（总结要点）添加AI解读功能
                 else if (index == 1) {
                   _showKeyPointsDialog(currentArticle);
                 }
               }
             },
      child: Padding(
            padding: const EdgeInsets.all(1), // 内边距调整为1像素
            child: Center(
                               child: Text(
                   text,
                   style: const TextStyle(
                     fontSize: 12,
                     fontWeight: FontWeight.w600,
                     color: Colors.white, // 白色字体
                     height: 1.2,
                   ),
                   textAlign: TextAlign.center,
                 ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建带动画的选项按钮（保留以备后用）
  Widget _buildAnimatedOptionButton(String text, int index) {
    return AnimatedScale(
      scale: _showFloatingOptions ? 1.0 : 0.0,
      duration: Duration(milliseconds: 200 + index * 50),
      curve: Curves.elasticOut,
      child: AnimatedOpacity(
        opacity: _showFloatingOptions ? 1.0 : 0.0,
        duration: Duration(milliseconds: 150 + index * 50),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _textColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () {
                print('选项按钮被点击: $text');
                // 这里可以添加具体的功能
                setState(() {
                  _showFloatingOptions = false; // 点击后隐藏选项
                });
              },
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

     // 构建选项按钮（保留原方法以防兼容性问题）
   Widget _buildOptionButton(String text, int index) {
     return _buildAnimatedOptionButton(text, index);
   }
 
   // 构建浮动按钮
   Widget _buildFloatingButton() {
     return Container(
       width: 72,
       height: 72,
       child: Material(
         color: Colors.transparent,
         child: InkWell(
           borderRadius: BorderRadius.circular(36),
           onTap: () {
             print('浮动按钮被点击！当前状态: $_showFloatingOptions');
             // 切换选项显示状态
             setState(() {
               _showFloatingOptions = !_showFloatingOptions;
             });
             print('状态已更新为: $_showFloatingOptions');
           },
           child: Padding(
             padding: const EdgeInsets.all(16),
             child: Image.asset(
               'assets/images/float_icon.png',
               width: 40,
               height: 40,
               fit: BoxFit.contain,
             ),
           ),
         ),
       ),
     );
   }
 }

/// 总结要点对话框Widget（内容撑开高度）
class _KeyPointsDialog extends StatefulWidget {
  final Article article;
  final AiService aiService;
  final UnifiedCacheService cacheService;
  final String promptType; // 提示词类型

  const _KeyPointsDialog({
    required this.article,
    required this.aiService,
    required this.cacheService,
    this.promptType = 'key_points', // 默认为key_points
  });

  @override
  State<_KeyPointsDialog> createState() => _KeyPointsDialogState();
}

class _KeyPointsDialogState extends State<_KeyPointsDialog> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _aiInterpretation = '';
  String? _errorMessage;
  bool _autoPlay = false; // 自动播放开关状态
  String _selectedVoice = 'zh-CN-XiaoxiaoNeural'; // 当前选择的音色
  bool _isAudioLoading = false; // 音频加载状态
  bool _isPlaying = false; // 音频播放状态
  bool _isPaused = false; // 是否处于暂停状态
  double _audioProgress = 0.0; // 音频播放进度
  String _currentTime = '00:00'; // 当前播放时间
  String _totalTime = '00:00'; // 总时长
  final TtsService _ttsService = TtsService();
  final MarkdownParserService _markdownParser = MarkdownParserService();

  @override
  void initState() {
    super.initState();
    _loadAiInterpretation();
  }

  Future<void> _loadAiInterpretation() async {
    try {
      // 合并标题和正文内容
      final combinedText = '${widget.article.title}\n\n${widget.article.content}';
      
      // 检查文本长度，如果太长则截断
      final maxTextLength = 8000; // 设置合理的最大长度
      final truncatedText = combinedText.length > maxTextLength 
          ? '${combinedText.substring(0, maxTextLength)}...'
          : combinedText;
      
      print('发送给AI的文本长度: ${truncatedText.length}');
      
      // 检查是否有完整的缓存（AI解读 + 音频）
      if (widget.cacheService.hasCompleteCache(truncatedText, widget.promptType, _selectedVoice, null)) {
        print('发现完整缓存，直接加载');
        final cachedData = widget.cacheService.getCompleteCache(truncatedText, widget.promptType, _selectedVoice, null);
        if (cachedData != null) {
          setState(() {
            _aiInterpretation = cachedData['aiResponse'].data.interpretation;
            _isLoading = false;
          });
          
          // 直接开始TTS播放，使用缓存数据
          _startTtsPlaybackWithCache(cachedData['audioData']);
          return;
        }
      }
      
      // 显示缓存状态
      final cacheStats = widget.cacheService.getCacheStats();
      print('当前缓存状态: ${cacheStats['aiCacheSize']}/${cacheStats['maxAiCacheSize']}');
      
      final response = await widget.aiService.interpretText(
        text: truncatedText,
        promptType: widget.promptType, // 使用传入的提示词类型
        maxTokens: 2000, // 增加token数量
      );

      if (response != null && response.success && response.data != null) {
        print('AI解读成功 - 结果长度: ${response.data!.interpretation.length}');
        setState(() {
          _aiInterpretation = response.data!.interpretation;
          _isLoading = false;
        });
        
        // AI解读完成后，自动开始TTS加载
        _startTtsLoading();
      } else {
        print('AI解读失败 - 错误: ${response?.error}');
        setState(() {
          _errorMessage = response?.error ?? 'AI解读失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '请求异常: $e';
        _isLoading = false;
      });
    }
  }

  // 开始TTS加载（根据自动播放设置决定是否播放）
  Future<void> _startTtsLoading() async {
    if (_aiInterpretation.isEmpty) return;
    
    try {
      // 清理Markdown格式，准备TTS
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 首先检查是否有缓存的音频数据
      final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
      if (cachedAudioData != null) {
        if (kDebugMode) {
          print('发现缓存的音频数据，大小: ${cachedAudioData.length} 字节');
        }
        
        setState(() {
          _isAudioLoading = false;
        });
        
        // 根据自动播放设置决定是否播放
        if (_autoPlay) {
          if (kDebugMode) {
            print('自动播放已开启，使用缓存音频开始播放');
          }
          
          // 使用缓存的音频数据播放
          await _startTtsPlaybackWithCache(cachedAudioData);
        } else {
          if (kDebugMode) {
            print('自动播放已关闭，缓存音频加载完成但不播放');
          }
          
          // 加载缓存音频但不播放
          await _loadCachedAudioWithoutPlayback(cachedAudioData);
        }
        return; // 有缓存，直接返回
      }
      
      // 没有缓存，开始TTS请求
      if (kDebugMode) {
        print('没有缓存音频数据，开始TTS请求');
      }
      
      setState(() {
        _isAudioLoading = true;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      // 获取TTS音频数据
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: _autoPlay, // 传递自动播放设置
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放错误: $error');
          }
        },
      );
      
      if (result['success'] == true) {
        // 缓存音频数据
        if (result['audioData'] != null) {
          widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          if (kDebugMode) {
            print('音频数据已缓存，大小: ${(result['audioData'] as Uint8List).length} 字节');
          }
        }
        
        setState(() {
          _isAudioLoading = false;
        });
        
        // 根据自动播放设置决定是否播放
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放已开启，开始播放音频');
          }
        } else {
          if (kDebugMode) {
            print('自动播放已关闭，音频加载完成但不播放');
          }
        }
      } else {
        setState(() {
          _isAudioLoading = false;
        });
        if (kDebugMode) {
          print('TTS加载失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
      });
      if (kDebugMode) {
        print('TTS加载异常: $e');
      }
    }
  }

  // 开始TTS音频播放
  Future<void> _startTtsPlayback() async {
    if (_aiInterpretation.isEmpty) return;
    
    // 检查是否有缓存的音频数据
    final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
    final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
    
    if (cachedAudioData != null) {
      if (kDebugMode) {
        print('使用缓存的音频数据，大小: ${cachedAudioData.length} 字节');
      }
      
      // 使用缓存的音频数据播放
      await _startTtsPlaybackWithCache(cachedAudioData);
      return;
    }
    
    // 没有缓存，开始TTS请求
    setState(() {
      _isAudioLoading = true;
      _isPlaying = false;
      _isPaused = false;
      _currentTime = '00:00';
    });
    
    try {
      // 清理Markdown格式，准备TTS播放
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 缓存播放时总是播放
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('缓存音频时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放错误: $error');
          }
        },
        cachedAudioData: cachedAudioData,
      );
      
      if (result['success'] == true) {
        if (kDebugMode) {
          print('缓存音频播放成功');
        }
        // 确保播放状态保持为true
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放模式，确保播放状态为true: $_isPlaying');
          }
        }
      } else {
        if (kDebugMode) {
          print('缓存音频播放失败: ${result['error']}');
        }
        // 缓存播放失败，清除缓存并重新获取
        widget.cacheService.clearTextCache(cleanedText);
        
        _startTtsPlayback(); // 递归调用重新获取
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print('缓存音频播放异常: $e');
      }
      // 清除缓存并重新获取
      widget.cacheService.clearTextCache(cleanedText);
    }
    
    // 没有缓存或缓存失效，重新获取音频
    setState(() {
      _isAudioLoading = true;
      _isPlaying = false;
      _isPaused = false;
      _currentTime = '00:00';
    });
    
    try {
      // 清理Markdown格式，准备TTS播放
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 手动播放时总是播放
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放错误: $error');
          }
        },
      );
      
      if (result['success'] == true) {
        // 缓存音频数据
        if (result['audioData'] != null) {
          widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          if (kDebugMode) {
            print('音频数据已缓存，大小: ${(result['audioData'] as Uint8List).length} 字节');
          }
        }
        
        setState(() {
          _isAudioLoading = false;
          _isPlaying = true;
          _isPaused = false;
        });
      } else {
        setState(() {
          _isAudioLoading = false;
        });
        if (kDebugMode) {
          print('TTS播放失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
      });
      if (kDebugMode) {
        print('TTS播放异常: $e');
      }
    }
  }

  // 使用缓存的音频数据开始播放
  Future<void> _startTtsPlaybackWithCache(Uint8List audioData) async {
    try {
      // 确保播放状态正确设置
      setState(() {
        _isAudioLoading = false;
        _isPlaying = true;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      if (kDebugMode) {
        print('开始播放缓存音频，播放状态: $_isPlaying');
      }
      
      // 直接使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: '', // 不需要文本，直接使用音频数据
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 缓存播放时总是播放
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放错误: $error');
          }
        },
        cachedAudioData: audioData,
      );
      
      if (result['success'] == true) {
        if (kDebugMode) {
          print('使用缓存音频播放成功');
        }
        // 确保播放状态保持为true
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放模式，确保播放状态为true: $_isPlaying');
          }
        }
      } else {
        if (kDebugMode) {
          print('使用缓存音频播放失败: ${result['error']}');
        }
        setState(() {
          _isPlaying = false;
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('使用缓存音频播放异常: $e');
      }
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    }
  }

  // 加载缓存音频但不播放（用于自动播放关闭时）
  Future<void> _loadCachedAudioWithoutPlayback(Uint8List audioData) async {
    try {
      if (kDebugMode) {
        print('加载缓存音频但不播放，音频大小: ${audioData.length} 字节');
      }
      
      setState(() {
        _isAudioLoading = false;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      if (kDebugMode) {
        print('缓存音频加载完成，等待用户手动播放');
      }
    } catch (e) {
      if (kDebugMode) {
        print('加载缓存音频异常: $e');
      }
      setState(() {
        _isAudioLoading = false;
      });
    }
  }

  // 停止TTS播放
  Future<void> _stopTtsPlayback() async {
    try {
      await _ttsService.pause();
      setState(() {
        _isPlaying = false;
        _isPaused = true;
      });
      if (kDebugMode) {
        print('TTS播放已暂停');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS暂停失败: $e');
      }
    }
  }

  // 快进
  Future<void> _fastForward() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(10); // 快进10秒
        if (kDebugMode) {
          print('TTS快进10秒');
        }
        
        // 如果之前是暂停状态，快进后恢复播放
        if (_isPaused) {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS快进失败: $e');
      }
    }
  }

  // 快退
  Future<void> _fastRewind() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(-10); // 快退10秒
        if (kDebugMode) {
          print('TTS快退10秒');
        }
        
        // 如果之前是暂停状态，快退后恢复播放
        if (_isPaused) {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS快退失败: $e');
      }
    }
  }

  // 显示音频选项抽屉
  void _showAudioOptionsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 自动播放开关
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.red[700],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        Text(
                          '自动播放',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'AI解读完成后自动播放音频',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoPlay,
                    onChanged: (bool value) {
                      setState(() {
                        _autoPlay = value;
                      });
                      
                      if (kDebugMode) {
                        print('自动播放开关状态: $_autoPlay');
                      }
                      
                      // 如果开启自动播放且当前有AI解读结果，立即开始播放
                      if (_autoPlay && _aiInterpretation.isNotEmpty && !_isPlaying && !_isPaused) {
                        if (kDebugMode) {
                          print('开启自动播放，开始播放音频');
                        }
                        setState(() {
                          _isPlaying = true;
                        });
                      }
                      // 如果关闭自动播放且当前正在播放，暂停播放
                      else if (!_autoPlay && _isPlaying) {
                        if (kDebugMode) {
                          print('关闭自动播放，暂停播放');
                        }
                        _ttsService.pause();
                        setState(() {
                          _isPlaying = false;
                          _isPaused = true;
                        });
                      }
                    },
                    activeColor: Colors.red[700],
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.red[700],
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[300],
                  ),
                ],
              ),
            ),
            // 音色选择
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
              children: [
                  Icon(
                    Icons.record_voice_over,
                    color: Colors.red[700],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音色选择',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '选择TTS语音的音色',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedVoice,
                      underline: Container(), // 移除默认下划线
                      items: [
                        DropdownMenuItem(
                          value: 'zh-CN-XiaoxiaoNeural',
                          child: Text('晓晓 (女声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-YunxiNeural',
                          child: Text('云希 (男声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-YunyangNeural',
                          child: Text('云扬 (男声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-XiaoyiNeural',
                          child: Text('晓伊 (女声)', style: TextStyle(fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'zh-CN-YunjianNeural',
                          child: Text('云健 (男声)', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null && newValue != _selectedVoice) {
                          setState(() {
                            _selectedVoice = newValue;
                          });
                          
                          if (kDebugMode) {
                            print('音色已更改为: $_selectedVoice');
                          }
                          
                          // 如果当前正在播放或暂停，停止播放并清除缓存
                          if (_isPlaying || _isPaused) {
                            _ttsService.stop();
                            setState(() {
                              _isPlaying = false;
                              _isPaused = false;
                              _currentTime = '00:00';
                            });
                            
                            // 清除文本缓存，确保使用新音色
                            final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
                            widget.cacheService.clearTextCache(cleanedText);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        // 关键修改：移除固定高度，让内容撑开
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9, // 最大高度限制
          minHeight: MediaQuery.of(context).size.height * 0.3,  // 最小高度限制
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 关键：让列根据内容调整大小
          children: [
            // 对话框头部
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(
                          _isLoading ? 'AI解读中' : widget.article.title,
                          style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 对话框内容 - 关键修改：移除Expanded，让内容自然撑开
            _isLoading
                ? _buildLoadingContent()
                : _buildAiContent(),
            // 音频播放器覆盖层
            if (!_isLoading && _aiInterpretation.isNotEmpty)
              _buildAudioPlayerOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.2, // 加载时使用固定高度
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiContent() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[300],
            ),
            const SizedBox(height: 16),
              Text(
                'AI解读失败',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
            // 标题行
            Text(
              'AI生成内容，请谨慎对待',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          const SizedBox(height: 16),
          // 使用Markdown解析服务渲染内容
          ..._markdownParser.parseMarkdown(_aiInterpretation),
        ],
      ),
    );
  }

  // 构建音频播放器覆盖层
  Widget _buildAudioPlayerOverlay() {
    return Container(
      height: 90, // 减少高度，使用浮动布局
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 中心主体：播放控制按钮
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 快退按钮
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      _fastRewind();
                    },
                    icon: Icon(
                      Icons.fast_rewind,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 播放按钮（中心）
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isAudioLoading ? Colors.grey[400] : Colors.red[700],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      if (_isPlaying) {
                        _stopTtsPlayback();
                      } else if (_isPaused) {
                        // 如果当前是暂停状态，直接恢复播放
                        _ttsService.resume();
                        setState(() {
                          _isPlaying = true;
                          _isPaused = false;
                        });
                        if (kDebugMode) {
                          print('音频已恢复播放');
                        }
                      } else {
                        // 如果既不是播放也不是暂停，则开始新播放
                        _startTtsPlayback();
                      }
                    },
                    icon: _isAudioLoading 
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying 
                                ? Icons.pause
                                : _isPaused
                                    ? Icons.play_arrow
                                    : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                // 快进按钮
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      _fastForward();
                    },
                    icon: Icon(
                      Icons.fast_forward,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 左上角：播放时间
          Positioned(
            left: 20,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _currentTime,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // 右上角：更多按钮
          Positioned(
            right: 20,
            top: 12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  _showAudioOptionsDrawer(context);
                },
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey[600],
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI解读对话框Widget
class _AiInterpretationDialog extends StatefulWidget {
  final Article article;
  final AiService aiService;
  final UnifiedCacheService cacheService;
  final String promptType; // 新增：提示词类型

  const _AiInterpretationDialog({
    required this.article,
    required this.aiService,
    required this.cacheService,
    this.promptType = 'summary', // 默认为summary
  });

  @override
  State<_AiInterpretationDialog> createState() => _AiInterpretationDialogState();
}

class _AiInterpretationDialogState extends State<_AiInterpretationDialog> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _aiInterpretation = '';
  String? _errorMessage;
  bool _autoPlay = false; // 自动播放开关状态
  String _selectedVoice = 'zh-CN-XiaoxiaoNeural'; // 当前选择的音色
  bool _isAudioLoading = false; // 音频加载状态
  bool _isPlaying = false; // 音频播放状态
  bool _isPaused = false; // 新增：是否处于暂停状态
  double _audioProgress = 0.0; // 音频播放进度
  String _currentTime = '00:00'; // 当前播放时间
  String _totalTime = '00:00'; // 总时长
  final TtsService _ttsService = TtsService();
  final MarkdownParserService _markdownParser = MarkdownParserService();
  


  @override
  void initState() {
    super.initState();
    _loadAiInterpretation();
  }

  Future<void> _loadAiInterpretation() async {
    try {
      // 合并标题和正文内容
      final combinedText = '${widget.article.title}\n\n${widget.article.content}';
      
      // 检查文本长度，如果太长则截断
      final maxTextLength = 8000; // 设置合理的最大长度
      final truncatedText = combinedText.length > maxTextLength 
          ? '${combinedText.substring(0, maxTextLength)}...'
          : combinedText;
      
      print('发送给AI的文本长度: ${truncatedText.length}');
      
      // 检查是否有完整的缓存（AI解读 + 音频）
      if (widget.cacheService.hasCompleteCache(truncatedText, widget.promptType, _selectedVoice, null)) {
        print('发现完整缓存，直接加载');
        final cachedData = widget.cacheService.getCompleteCache(truncatedText, widget.promptType, _selectedVoice, null);
        if (cachedData != null) {
          setState(() {
            _aiInterpretation = cachedData['aiResponse'].data.interpretation;
            _isLoading = false;
          });
          
          // 直接开始TTS播放，使用缓存数据
          _startTtsPlaybackWithCache(cachedData['audioData']);
          return;
        }
      }
      
      // 显示缓存状态
      final cacheStats = widget.cacheService.getCacheStats();
      print('当前缓存状态: ${cacheStats['aiCacheSize']}/${cacheStats['maxAiCacheSize']}');
      
      final response = await widget.aiService.interpretText(
        text: truncatedText,
        promptType: widget.promptType, // 使用传入的提示词类型
        maxTokens: 2000, // 增加token数量
      );

      if (response != null && response.success && response.data != null) {
        print('AI解读成功 - 结果长度: ${response.data!.interpretation.length}');
        setState(() {
          _aiInterpretation = response.data!.interpretation;
          _isLoading = false;
        });
        
        // AI解读完成后，自动开始TTS加载
        _startTtsLoading();
      } else {
        print('AI解读失败 - 错误: ${response?.error}');
        setState(() {
          _errorMessage = response?.error ?? 'AI解读失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '请求异常: $e';
        _isLoading = false;
      });
    }
  }
  
  // 使用缓存的音频数据开始播放
  Future<void> _startTtsPlaybackWithCache(Uint8List audioData) async {
    try {
      // 确保播放状态正确设置
      setState(() {
        _isAudioLoading = false;
        _isPlaying = true;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      if (kDebugMode) {
        print('开始播放缓存音频，播放状态: $_isPlaying');
      }
      
      // 直接使用缓存的音频数据播放
      final result = await _ttsService.streamTtsAndPlay(
        text: '', // 不需要文本，直接使用音频数据
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: true, // 缓存播放时总是播放
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('缓存音频播放错误: $error');
          }
        },
        cachedAudioData: audioData,
      );
      
      if (result['success'] == true) {
        if (kDebugMode) {
          print('使用缓存音频播放成功');
        }
        // 确保播放状态保持为true
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放模式，确保播放状态为true: $_isPlaying');
          }
        }
      } else {
        if (kDebugMode) {
          print('使用缓存音频播放失败: ${result['error']}');
        }
        setState(() {
          _isPlaying = false;
          _isAudioLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('使用缓存音频播放异常: $e');
      }
      setState(() {
        _isPlaying = false;
        _isAudioLoading = false;
      });
    }
  }

  // 加载缓存音频但不播放（用于自动播放关闭时）
  Future<void> _loadCachedAudioWithoutPlayback(Uint8List audioData) async {
    try {
      if (kDebugMode) {
        print('加载缓存音频但不播放，音频大小: ${audioData.length} 字节');
      }
      
      setState(() {
        _isAudioLoading = false;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      if (kDebugMode) {
        print('缓存音频加载完成，等待用户手动播放');
      }
    } catch (e) {
      if (kDebugMode) {
        print('加载缓存音频异常: $e');
      }
      setState(() {
        _isAudioLoading = false;
      });
    }
  }

  // 开始TTS加载（根据自动播放设置决定是否播放）
  Future<void> _startTtsLoading() async {
    if (_aiInterpretation.isEmpty) return;
    
    try {
      // 清理Markdown格式，准备TTS
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 首先检查是否有缓存的音频数据
      final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
      if (cachedAudioData != null) {
        if (kDebugMode) {
          print('发现缓存的音频数据，大小: ${cachedAudioData.length} 字节');
        }
        
        setState(() {
          _isAudioLoading = false;
        });
        
        // 根据自动播放设置决定是否播放
        if (_autoPlay) {
          if (kDebugMode) {
            print('自动播放已开启，使用缓存音频开始播放');
          }
          
          // 使用缓存的音频数据播放
          await _startTtsPlaybackWithCache(cachedAudioData);
        } else {
          if (kDebugMode) {
            print('自动播放已关闭，缓存音频加载完成但不播放');
          }
          
          // 加载缓存音频但不播放
          await _loadCachedAudioWithoutPlayback(cachedAudioData);
        }
        return; // 有缓存，直接返回
      }
      
      // 没有缓存，开始TTS请求
      if (kDebugMode) {
        print('没有缓存音频数据，开始TTS请求');
      }
      
      setState(() {
        _isAudioLoading = true;
        _isPlaying = false;
        _isPaused = false;
        _currentTime = '00:00';
      });
      
      // 获取TTS音频数据
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        autoPlay: _autoPlay, // 传递自动播放设置
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('TTS时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放错误: $error');
          }
        },
      );
      
      if (result['success'] == true) {
        // 缓存音频数据
        if (result['audioData'] != null) {
          widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          if (kDebugMode) {
            print('音频数据已缓存，大小: ${(result['audioData'] as Uint8List).length} 字节');
          }
        }
        
        setState(() {
          _isAudioLoading = false;
        });
        
        // 根据自动播放设置决定是否播放
        if (_autoPlay) {
          setState(() {
            _isPlaying = true;
          });
          if (kDebugMode) {
            print('自动播放已开启，开始播放音频');
          }
        } else {
          if (kDebugMode) {
            print('自动播放已关闭，音频加载完成但不播放');
          }
        }
      } else {
        setState(() {
          _isAudioLoading = false;
        });
        if (kDebugMode) {
          print('TTS加载失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
      });
      if (kDebugMode) {
        print('TTS加载异常: $e');
      }
    }
  }
  
  // 开始TTS音频播放
  Future<void> _startTtsPlayback() async {
    if (_aiInterpretation.isEmpty) return;
    
    // 检查是否有缓存的音频数据
    final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
    final cachedAudioData = widget.cacheService.getAudioCache(cleanedText, _selectedVoice);
    
    if (cachedAudioData != null) {
      if (kDebugMode) {
        print('使用缓存的音频数据，大小: ${cachedAudioData.length} 字节');
      }
      
      // 使用缓存的音频数据播放
      await _startTtsPlaybackWithCache(cachedAudioData);
      return;
    }
    
    // 没有缓存，开始TTS请求
    setState(() {
      _isAudioLoading = true;
      _isPlaying = false;
      _isPaused = false;
      _audioProgress = 0.0;
      _currentTime = '00:00';
    });
    

    
    try {
      // 清理Markdown格式，准备TTS播放
      final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
      
      // 使用新的TTS播放方法
      final result = await _ttsService.streamTtsAndPlay(
        text: cleanedText,
        voice: _selectedVoice,
        language: 'zh-CN',
        onTimeUpdate: (time) {
          setState(() {
            try {
              _currentTime = time.trim();
              if (kDebugMode) {
                print('时间更新: $_currentTime');
              }
            } catch (e) {
              if (kDebugMode) {
                print('时间解析错误: $e');
              }
              _currentTime = '00:00';
            }
          });
        },
        onComplete: () {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS音频播放完成');
          }
        },
        onError: (error) {
          setState(() {
            _isAudioLoading = false;
            _isPlaying = false;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('TTS播放错误: $error');
          }
        },
      );
      
      if (result['success'] == true) {
        // 缓存音频数据
        if (result['audioData'] != null) {
          widget.cacheService.setAudioCache(cleanedText, _selectedVoice, result['audioData'] as Uint8List);
          if (kDebugMode) {
            print('音频数据已缓存，大小: ${(result['audioData'] as Uint8List).length} 字节');
          }
        }
        
        setState(() {
          _isAudioLoading = false;
          _isPlaying = true;
        });
        
        if (kDebugMode) {
          print('TTS播放开始成功');
        }
      } else {
        setState(() {
          _isAudioLoading = false;
          _isPlaying = false;
        });
        
        if (kDebugMode) {
          print('TTS播放开始失败: ${result['error']}');
        }
      }
    } catch (e) {
      setState(() {
        _isAudioLoading = false;
        _isPlaying = false;
      });
      
      if (kDebugMode) {
        print('TTS播放异常: $e');
      }
    }
  }
  
  // 暂停音频播放
  void _stopTtsPlayback() {
    if (_isPlaying) {
      _ttsService.pause(); // 暂停而不是停止
      setState(() {
        _isPlaying = false;
        _isPaused = true; // 标记为暂停状态
      });
      if (kDebugMode) {
        print('音频已暂停');
      }
    }
  }

  // 快退播放
  void _fastRewind() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(-10); // 快退10秒
        if (kDebugMode) {
          print('快退10秒');
        }
        
        // 如果当前是暂停状态，快退后保持暂停
        // 如果当前是播放状态，快退后继续播放
        if (_isPaused) {
          // 快退后恢复播放
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('快退后恢复播放');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('快退失败: $e');
      }
      // 快退失败时，尝试恢复播放状态
      if (_isPaused) {
        try {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        } catch (resumeError) {
          if (kDebugMode) {
            print('快退失败后恢复播放也失败: $resumeError');
          }
        }
      }
    }
  }

  // 快进播放
  void _fastForward() async {
    try {
      if (_isPlaying || _isPaused) {
        await _ttsService.seekToRelative(10); // 快进10秒
        if (kDebugMode) {
          print('快进10秒');
        }
        
        // 如果当前是暂停状态，快进后保持暂停
        // 如果当前是播放状态，快进后继续播放
        if (_isPaused) {
          // 快进后恢复播放
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
          if (kDebugMode) {
            print('快进后恢复播放');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('快进失败: $e');
      }
      // 快进失败时，尝试恢复播放状态
      if (_isPaused) {
        try {
          await _ttsService.resume();
          setState(() {
            _isPlaying = true;
            _isPaused = false;
          });
        } catch (resumeError) {
          if (kDebugMode) {
            print('快进失败后恢复播放也失败: $resumeError');
          }
        }
      }
    }
  }
  

  
  // 显示音频选项抽屉
  void _showAudioOptionsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
              // 拖拽指示器
                Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                  decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                Text(
                      '音频设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // 自动播放开关
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: Colors.red[700],
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                        Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '自动播放',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'AI解读完成后自动播放音频',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                    Switch(
                      value: _autoPlay,
                      onChanged: (bool value) {
                        setState(() {
                          _autoPlay = value;
                        });
                        
                        if (kDebugMode) {
                          print('自动播放开关状态: $_autoPlay');
                        }
                        
                        // 如果开启自动播放且当前有AI解读结果，立即开始播放
                        if (_autoPlay && _aiInterpretation.isNotEmpty && !_isPlaying && !_isPaused) {
                          if (kDebugMode) {
                            print('开启自动播放，开始播放音频');
                          }
                          setState(() {
                            _isPlaying = true;
                          });
                        }
                        // 如果关闭自动播放且当前正在播放，暂停播放
                        else if (!_autoPlay && _isPlaying) {
                          if (kDebugMode) {
                            print('关闭自动播放，暂停播放');
                          }
                          _ttsService.pause();
                          setState(() {
                            _isPlaying = false;
                            _isPaused = true;
                          });
                        }
                      },
                      activeColor: Colors.red[700],
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.red[700],
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ],
                ),
              ),
              // 音色选择
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      color: Colors.red[700],
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '音色选择',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '选择TTS语音的音色',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedVoice,
                        underline: Container(), // 移除默认下划线
                        items: [
                          DropdownMenuItem(
                            value: 'zh-CN-XiaoxiaoNeural',
                            child: Text('晓晓 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-YunxiNeural',
                            child: Text('云希 (男声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-YunyangNeural',
                            child: Text('云扬 (男声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaoyiNeural',
                            child: Text('晓伊 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-YunfengNeural',
                            child: Text('云枫 (男声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaohanNeural',
                            child: Text('晓涵 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaomoNeural',
                            child: Text('晓墨 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaoxuanNeural',
                            child: Text('晓萱 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: 'zh-CN-XiaoyanNeural',
                            child: Text('晓颜 (女声)', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedVoice) {
                            setState(() {
                              _selectedVoice = newValue;
                            });
                            
                            if (kDebugMode) {
                              print('音色已更改为: $_selectedVoice');
                            }
                            
                            // 如果当前正在播放，停止播放并清除缓存
                            if (_isPlaying || _isPaused) {
                              _ttsService.stop();
                              setState(() {
                                _isPlaying = false;
                                _isPaused = false;
                                _currentTime = '00:00';
                              });
                              
                              // 清除缓存，因为音色改变了
                              final cleanedText = Article.cleanMarkdownForTts(_aiInterpretation);
                              widget.cacheService.clearTextCache(cleanedText);
                              
                              if (kDebugMode) {
                                print('音色改变，已停止播放并清除缓存');
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: _isLoading 
            ? MediaQuery.of(context).size.height * 0.3  // 加载时使用更小高度
            : MediaQuery.of(context).size.height * 0.85, // 加载完成后使用正常高度
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // 对话框头部
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
                    child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading ? 'AI解读中' : widget.article.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 对话框内容
            _isLoading
                ? _buildLoadingContent()
                : Expanded(
                    child: _buildAiContent(),
                  ),
            // 音频播放器覆盖层
            if (!_isLoading && _aiInterpretation.isNotEmpty)
              _buildAudioPlayerOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.2, // 调整为屏幕高度的五分之一
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiContent() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 20),
              Text(
                'AI解读失败',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loadAiInterpretation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Text(
              'AI生成内容，请谨慎对待',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          // 使用Markdown解析服务渲染内容
          ..._markdownParser.parseMarkdown(_aiInterpretation),
        ],
      ),
    );
  }
  
  // 构建音频播放器覆盖层
  Widget _buildAudioPlayerOverlay() {
    return Container(
      height: 90, // 减少高度，使用浮动布局
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 中心主体：播放控制按钮
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 快退按钮
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      _fastRewind();
                    },
                    icon: Icon(
                      Icons.fast_rewind,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // 播放按钮（中心）
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isAudioLoading ? Colors.grey[400] : Colors.red[700],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      if (_isPlaying) {
                        _stopTtsPlayback();
                      } else if (_isPaused) {
                        // 如果当前是暂停状态，直接恢复播放
                        _ttsService.resume();
                        setState(() {
                          _isPlaying = true;
                          _isPaused = false;
                        });
                        if (kDebugMode) {
                          print('音频已恢复播放');
                        }
                      } else {
                        // 如果既不是播放也不是暂停，则开始新播放
                        _startTtsPlayback();
                      }
                    },
                    icon: _isAudioLoading 
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying 
                                ? Icons.pause
                                : _isPaused
                                    ? Icons.play_arrow
                                    : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                // 快进按钮
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isAudioLoading ? null : () {
                      _fastForward();
                    },
                    icon: Icon(
                      Icons.fast_forward,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 左上角：播放时间
          Positioned(
            left: 20,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _currentTime,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // 右上角：更多按钮
          Positioned(
            right: 20,
            top: 12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  _showAudioOptionsDrawer(context);
                },
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey[600],
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 全文内容对话框Widget（恢复原来的查看更多功能）
class _FullContentDialog extends StatelessWidget {
  final Article article;

  const _FullContentDialog({
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // 对话框头部
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 对话框内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RichContentWidget(
                  contentItems: article.parseContentItems(),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                  textColor: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
