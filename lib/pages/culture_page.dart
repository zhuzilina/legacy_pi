import 'package:flutter/material.dart';
import 'package:legacy_pi/widgets/ai_interpretation_dialog.dart';
import 'package:legacy_pi/widgets/key_points_dialog.dart';
import 'package:legacy_pi/pages/chat_page.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'dart:async';
import '../services/news_api_service.dart';
import '../services/ai_service.dart';
import '../services/unified_cache_service.dart';
import '../services/md_docs_api_service.dart';
import '../models/content_item.dart';
import '../models/article.dart';
import '../widgets/rich_content_widget.dart';
import '../widgets/keep_alive_category_view.dart';
import '../l10n/app_localizations.dart';

class CulturePage extends StatefulWidget {
  const CulturePage({super.key});

  @override
  State<CulturePage> createState() => CulturePageState();
}

class CulturePageState extends State<CulturePage> with TickerProviderStateMixin {
  final UnifiedCacheService _cacheService = UnifiedCacheService();
  late TabController _tabController;
  
  // 每个分类的页面位置状态
  final Map<String, int> _categoryPageIndexMap = {};
  
  // 每个分类的KeepAliveCategoryView实例
  final Map<String, GlobalKey<KeepAliveCategoryViewState>> _categoryViewKeys = {};
  
     // API 服务
   final NewsApiService _newsApiService = NewsApiService();
   final AiService _aiService = AiService();
   final MdDocsApiService _mdDocsApiService = MdDocsApiService();
   
     // 分类数据
  late List<String> _categories;
  int _currentTabIndex = 0;
  
  // 各分类的数据状态
  final Map<String, bool> _isLoadingMap = {};
  final Map<String, String> _errorMessageMap = {};
  final Map<String, List<Article>> _articlesMap = {};
  
  // 统一配色方案：白底黑字
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;
  


  @override
  void initState() {
    super.initState();
    
    // 恢复页面状态
    _restorePageState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 获取本地化字符串
    final l10n = AppLocalizations.of(context)!;
    _categories = [l10n.news, l10n.spirit, l10n.people, l10n.partyHistory];
    
    // 初始化TabController（如果还没有初始化）
    try {
      // 尝试访问 _tabController，如果未初始化会抛出异常
      _tabController.length;
    } catch (e) {
      // 如果未初始化，则创建新的TabController
      _tabController = TabController(length: _categories.length, vsync: this);
      
      // 初始化各分类的状态
      for (final category in _categories) {
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = '';
        _articlesMap[category] = [];
      }
      
      // 检查是否需要加载默认分类（新闻）的数据
      // 只有在没有缓存状态时才加载默认数据
      _checkAndLoadDefaultData();
      
      // 监听Tab切换
      _tabController.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    // 保存页面状态
    _savePageState();
    
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  // 悬浮按钮回调方法 - 现在由主页调用
  void handleStudyFullText() {
    final currentArticle = _getCurrentArticle();
    if (currentArticle != null) {
      _showAiInterpretationDialog(currentArticle);
    }
  }
  
  void handleSummarizeKeyPoints() {
    final currentArticle = _getCurrentArticle();
    if (currentArticle != null) {
      _showKeyPointsDialog(currentArticle);
    }
  }
  
  void handleEnterConversation() {
    final currentArticle = _getCurrentArticle();
    if (currentArticle != null) {
      _navigateToChatPage(currentArticle);
    }
  }

  // 获取当前文章
  Article? _getCurrentArticle() {
    if (_currentTabIndex >= 0 && _currentTabIndex < _categories.length) {
      final category = _categories[_currentTabIndex];
      final articles = _articlesMap[category] ?? [];
      if (articles.isNotEmpty) {
        // 从KeepAliveCategoryView获取当前页面位置
        final viewKey = _categoryViewKeys[category];
        if (viewKey?.currentState != null) {
          final currentPage = viewKey!.currentState!.getCurrentPage();
          if (currentPage >= 0 && currentPage < articles.length) {
            return articles[currentPage];
          }
        }
      }
    }
    return null;
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      final oldIndex = _currentTabIndex;
      final newIndex = _tabController.index;
      
      // 保存当前分类的页面位置
      if (oldIndex >= 0 && oldIndex < _categories.length) {
        final oldCategory = _categories[oldIndex];
        // 从KeepAliveCategoryView获取当前页面位置
        final oldViewKey = _categoryViewKeys[oldCategory];
        if (oldViewKey?.currentState != null) {
          final currentPage = oldViewKey!.currentState!.getCurrentPage();
          _categoryPageIndexMap[oldCategory] = currentPage;
          print('保存分类 $oldCategory 的页面位置: $currentPage');
        }
      }
      
      setState(() {
        _currentTabIndex = newIndex;
      });
      
      // 恢复新分类的页面位置
      final newCategory = _categories[newIndex];
      final savedPageIndex = _categoryPageIndexMap[newCategory] ?? 0;
      
      print('切换到分类 $newCategory，恢复页面位置: $savedPageIndex');
      
      // 如果该分类还没有数据，则加载
      if (_articlesMap[newCategory]!.isEmpty && !_isLoadingMap[newCategory]!) {
        _loadArticlesForCategory(newCategory);
      }
      
      // 延迟设置新分类的页面位置，确保KeepAliveCategoryView已经构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newViewKey = _categoryViewKeys[newCategory];
        if (newViewKey?.currentState != null && savedPageIndex > 0) {
          print('设置分类 $newCategory 的页面位置: $savedPageIndex');
          newViewKey!.currentState!.setPagePosition(savedPageIndex);
        }
      });
      
      // 保存页面状态
      _savePageState();
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
      
      // 根据分类选择不同的数据源
      if (category == '新闻') {
        await _loadNewsArticles(category);
      } else {
        // 精神、人物、党史分类使用MD文档API
        await _loadMdDocsArticles(category);
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

    // 预加载文章中的图片
    _preloadArticleImages(articles);

    print('$category 文章加载完成，共 ${articles.length} 篇');
  }

  // 加载MD文档数据（用于精神、人物、党史分类）
  Future<void> _loadMdDocsArticles(String category) async {
    try {
      print('开始从MD文档API加载 $category 分类数据...');
      
      // 获取文档ID列表
      final response = await _mdDocsApiService.getDocumentIdsByCategory(
        category: category,
      );
      
      if (response == null) {
        setState(() {
          _isLoadingMap[category] = false;
          _errorMessageMap[category] = '无法连接到MD文档服务器';
        });
        return;
      }
      
      if (response.msg != 'success') {
        setState(() {
          _isLoadingMap[category] = false;
          _errorMessageMap[category] = response.error ?? '获取MD文档ID列表失败';
        });
        return;
      }
      
      if (response.articleIds.isEmpty) {
        setState(() {
          _isLoadingMap[category] = false;
          _errorMessageMap[category] = '暂无可用文档';
        });
        return;
      }
      
      print('获取到 ${response.articleIds.length} 个文档ID');
      
      // 批量获取文档内容
      final articles = <Article>[];
      for (final documentId in response.articleIds) {
        try {
          // 获取完整文档内容
          final content = await _mdDocsApiService.getDocumentContent(documentId);
          if (content != null) {
            // 使用Article的fromMarkdown方法解析内容
            final article = _mdDocsApiService.convertToArticle(documentId, content);
            articles.add(article);
          } else {
            print('获取文档 $documentId 内容失败');
          }
        } catch (e) {
          print('获取文档 $documentId 内容失败: $e');
        }
      }
      
      setState(() {
        _articlesMap[category] = articles;
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = '';
      });
      
      // 预加载文章中的图片
      _preloadArticleImages(articles);
      
      print('$category MD文档加载完成，共 ${articles.length} 篇');
      
    } catch (e) {
      print('加载 $category MD文档时发生错误: $e');
      setState(() {
        _isLoadingMap[category] = false;
        _errorMessageMap[category] = '加载MD文档时发生错误: $e';
      });
    }
  }

  // 检查并加载默认数据
  Future<void> _checkAndLoadDefaultData() async {
    try {
      // 检查是否有保存的状态
      final state = await _cacheService.pageStateCacheService.getCulturePageState();
      
      if (state != null) {
        // 有保存的状态，不需要加载默认数据
        print('检测到保存的页面状态，跳过默认数据加载');
        return;
      }
      
      // 没有保存的状态，加载默认分类（新闻）的数据
      print('没有保存的页面状态，加载默认数据');
      _loadArticlesForCategory(_categories[0]);
    } catch (e) {
      print('检查默认数据加载失败: $e');
      // 出错时加载默认数据
      _loadArticlesForCategory(_categories[0]);
    }
  }


  // 预加载文章中的图片
  Future<void> _preloadArticleImages(List<Article> articles) async {
    try {
      // 收集所有文章中的图片URL
      final imageUrls = <String>[];
      for (final article in articles) {
        // 解析文章内容，提取图片URL
        final contentItems = await article.parseContentItems(cacheService: _cacheService);
        for (final item in contentItems) {
          if (item.type == ContentItemType.image || item.type == ContentItemType.imageWithText) {
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
              imageUrls.add(item.imageUrl!);
            }
          }
        }
      }
      
      if (imageUrls.isNotEmpty) {
        print('开始预加载 ${imageUrls.length} 张图片...');
        // 使用统一缓存服务预加载图片
        await _cacheService.preloadArticleImages(imageUrls);
        print('图片预加载完成');
      }
    } catch (e) {
      print('预加载图片失败: $e');
    }
  }

  // 保存页面状态
  Future<void> _savePageState() async {
    try {
      // 保存当前分类的页面位置到内存映射
      if (_categories.isNotEmpty && _currentTabIndex < _categories.length) {
        final currentCategory = _categories[_currentTabIndex];
        // 从KeepAliveCategoryView获取当前页面位置
        final viewKey = _categoryViewKeys[currentCategory];
        if (viewKey?.currentState != null) {
          final currentPage = viewKey!.currentState!.getCurrentPage();
          _categoryPageIndexMap[currentCategory] = currentPage;
          
          // 保存分类页面位置映射到持久化存储
          await _cacheService.pageStateCacheService.saveCategoryPagePositions(_categoryPageIndexMap);
          
          await _cacheService.pageStateCacheService.saveCulturePageState(
            bottomTabIndex: 1, // 文化页面在底部TabBar中的索引
            pageTabIndex: _currentTabIndex,
            currentPageIndex: currentPage,
            currentCategory: currentCategory,
          );
          
          // 状态变化由KeepAliveCategoryView自动管理，不需要通知父组件
          
          print('文化页面状态已保存: 底部Tab=1, 页面Tab=$_currentTabIndex, 当前页=$currentPage, 分类=$currentCategory');
        }
      }
    } catch (e) {
      print('保存页面状态失败: $e');
    }
  }

  // 恢复页面状态
  Future<void> _restorePageState() async {
    try {
      // 恢复分类页面位置映射
      final categoryPagePositions = await _cacheService.pageStateCacheService.getCategoryPagePositions();
      _categoryPageIndexMap.addAll(categoryPagePositions);
      print('恢复分类页面位置映射: $categoryPagePositions');
      
      final state = await _cacheService.pageStateCacheService.getCulturePageState();
      if (state != null) {
        final pageTabIndex = state['pageTabIndex'] as int? ?? 0;
        final currentPageIndex = state['currentPageIndex'] as int? ?? 0;
        final currentCategory = state['currentCategory'] as String? ?? '';
        
        // 确保索引在有效范围内
        if (pageTabIndex >= 0 && pageTabIndex < _categories.length) {
          setState(() {
            _currentTabIndex = pageTabIndex;
          });
          
          // 如果TabController已初始化，设置正确的索引
          if (_tabController.length > 0 && pageTabIndex < _tabController.length) {
            _tabController.index = pageTabIndex;
          }
          
          // 确保对应分类的数据已加载
          final category = _categories[pageTabIndex];
          if (_articlesMap[category]!.isEmpty && !_isLoadingMap[category]!) {
            print('恢复状态时加载分类数据: $category');
            _loadArticlesForCategory(category);
          }
          
          // 延迟设置页面位置，确保KeepAliveCategoryView已经构建完成
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final viewKey = _categoryViewKeys[category];
            if (viewKey?.currentState != null && currentPageIndex > 0) {
              print('状态恢复：设置分类 $category 的页面位置: $currentPageIndex');
              viewKey!.currentState!.setPagePosition(currentPageIndex);
            }
          });
          
          print('页面状态已恢复: Tab=$pageTabIndex, Page=$currentPageIndex, Category=$currentCategory');
        }
      }
    } catch (e) {
      print('恢复页面状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor,
      child: Column(
        children: [
          // TabBar
          Container(
            height: 48,
            color: _backgroundColor,
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
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) => _buildCategoryView(category)).toList(),
            ),
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

    // 为每个分类创建唯一的GlobalKey
    if (!_categoryViewKeys.containsKey(category)) {
      _categoryViewKeys[category] = GlobalKey<KeepAliveCategoryViewState>();
    }

    return KeepAliveCategoryView(
      key: _categoryViewKeys[category],
      category: category,
      articles: articles,
      isLoading: isLoading,
      errorMessage: errorMessage,
      cacheService: _cacheService,
      onShowFullContent: _showFullContentDialog,
      onShowAiInterpretation: (article) => _showAiInterpretationDialog(article),
      onShowKeyPoints: _showKeyPointsDialog,
      onNavigateToChat: _navigateToChatPage,
    );
  }


           // 显示全文内容对话框
     void _showFullContentDialog(Article article) {
       // 使用 showGeneralDialog 并设置较低的层级，确保浮动按钮能够显示在最上面
       showGeneralDialog(
         context: context,
         barrierDismissible: true,
         barrierColor: Colors.black54,
         barrierLabel: '',
         transitionDuration: const Duration(milliseconds: 300),
         pageBuilder: (context, animation, secondaryAnimation) {
           return TweenAnimationBuilder<double>(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOutBack,
             tween: Tween(begin: 0.0, end: 1.0),
             builder: (context, scale, child) {
               return Transform.scale(
                 scale: scale,
                 child: _FullContentDialog(
                   article: article,
                   cacheService: _cacheService,
                   onClose: () {
                     Navigator.of(context).pop();
                   },
                 ),
               );
             },
           );
         },
         transitionBuilder: (context, animation, secondaryAnimation, child) {
           return FadeTransition(
             opacity: animation,
             child: child,
           );
         },
       );
     }
     
     // 显示AI解读对话框
     void _showAiInterpretationDialog(Article article, {String promptType = 'summary'}) {
       Navigator.of(context).push(
         PageRouteBuilder(
           opaque: false,
           barrierColor: Colors.transparent,
           barrierDismissible: true,
           pageBuilder: (context, animation, secondaryAnimation) {
             return TweenAnimationBuilder<double>(
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeOutBack,
               tween: Tween(begin: 0.0, end: 1.0),
               builder: (context, scale, child) {
                 return Transform.scale(
                   scale: scale,
                   child: AiInterpretationDialog(
                     article: article,
                     aiService: _aiService,
                     cacheService: _cacheService,
                     promptType: promptType,
                   ),
                 );
               },
             );
           },
           transitionsBuilder: (context, animation, secondaryAnimation, child) {
             return FadeTransition(
               opacity: animation,
               child: child,
             );
           },
         ),
       );
     }
     
     // 显示总结要点对话框（内容撑开高度）
     void _showKeyPointsDialog(Article article) {
       Navigator.of(context).push(
         PageRouteBuilder(
           opaque: false,
           barrierColor: Colors.transparent,
           barrierDismissible: true,
           pageBuilder: (context, animation, secondaryAnimation) {
             return TweenAnimationBuilder<double>(
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeOutBack,
               tween: Tween(begin: 0.0, end: 1.0),
               builder: (context, scale, child) {
                 return Transform.scale(
                   scale: scale,
                   child: KeyPointsDialog(
                     article: article,
                     aiService: _aiService,
                     cacheService: _cacheService,
                     promptType: 'key_points',
                   ),
                 );
               },
             );
           },
           transitionsBuilder: (context, animation, secondaryAnimation, child) {
             return FadeTransition(
               opacity: animation,
               child: child,
             );
           },
         ),
       );
     }
     
     // 导航到对话页面
     void _navigateToChatPage(Article article) {
       Navigator.of(context).push(
         MaterialPageRoute(
           builder: (context) => ChatPage(article: article),
         ),
       );
     }


 }



/// 全文内容对话框Widget（恢复原来的查看更多功能）
class _FullContentDialog extends StatelessWidget {
  final Article article;
  final UnifiedCacheService cacheService;
  final VoidCallback? onClose;

  const _FullContentDialog({
    required this.article,
    required this.cacheService,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: DeferredPointerHandler( // 包裹根组件，处理超出边界的点击事件
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black54,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none, // 允许子元素移出Stack边界
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.72, // 调整为屏幕高度的72%
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 文章标题（现在在滚动区域内）
                          Text(
                            article.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 内容标题
                          Text(
                            AppLocalizations.of(context)!.articleContent,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 使用RichContentWidget显示内容，支持图片和文本选择
                          FutureBuilder<List<ContentItem>>(
                            future: article.parseContentItems(cacheService: cacheService),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return RichContentWidget(
                                  contentItems: snapshot.data!,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textColor: Colors.black87,
                                  enableScrolling: false, // 在弹窗中禁用滚动
                                  article: article, // 传递文章对象
                                  contextText: article.content, // 传递文章内容作为上下文
                                  cacheService: cacheService, // 传递缓存服务
                                );
                              } else {
                                return const Center(child: CircularProgressIndicator());
                              }
                            },
                          ),
                          const SizedBox(height: 20), // 底部留出空间
                        ],
                      ),
                    ),
                  ),
                ),
                // 底部悬浮关闭按钮 - 位于弹窗水平中心，距离弹窗底部-67像素
                Positioned(
                  bottom: -67,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DeferPointer( // 包裹需要响应事件的组件
                      child: GestureDetector(
                        onTap: () {
                          if (onClose != null) {
                            onClose!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
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
}
