import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/content_item.dart';
import '../services/unified_cache_service.dart';
import '../widgets/rich_content_widget.dart';
import '../l10n/app_localizations.dart';

/// 保持状态的分类视图组件
/// 使用 AutomaticKeepAliveClientMixin 来保持页面状态，避免切换Tab时重新构建
class KeepAliveCategoryView extends StatefulWidget {
  final String category;
  final List<Article> articles;
  final bool isLoading;
  final String errorMessage;
  final UnifiedCacheService cacheService;
  final Function(Article) onShowFullContent;
  final Function(Article) onShowAiInterpretation;
  final Function(Article) onShowKeyPoints;
  final Function(Article) onNavigateToChat;

  const KeepAliveCategoryView({
    super.key,
    required this.category,
    required this.articles,
    required this.isLoading,
    required this.errorMessage,
    required this.cacheService,
    required this.onShowFullContent,
    required this.onShowAiInterpretation,
    required this.onShowKeyPoints,
    required this.onNavigateToChat,
  });

  @override
  State<KeepAliveCategoryView> createState() => KeepAliveCategoryViewState();
}

class KeepAliveCategoryViewState extends State<KeepAliveCategoryView> 
    with AutomaticKeepAliveClientMixin {
  
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // 统一配色方案：白底黑字
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print('KeepAliveCategoryView初始化: ${widget.category}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 设置当前页面位置
  void setCurrentPage(int page) {
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  // 跳转到指定页面
  void jumpToPage(int page) {
    if (_pageController.hasClients && page >= 0 && page < widget.articles.length) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 获取当前页面位置
  int getCurrentPage() {
    return _currentPage;
  }

  // 设置页面位置（不带动画）
  void setPagePosition(int page) {
    if (page >= 0 && page < widget.articles.length) {
      setState(() {
        _currentPage = page;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(page);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 必须调用 super.build(context)
    super.build(context);
    
    print('KeepAliveCategoryView构建: ${widget.category}, 文章数量: ${widget.articles.length}, 当前页: $_currentPage');

    if (widget.isLoading) {
      return _buildLoadingView();
    } else if (widget.errorMessage.isNotEmpty) {
      return _buildErrorView();
    } else if (widget.articles.isEmpty) {
      return _buildEmptyView();
    } else {
      return _buildArticlePageView();
    }
  }

  // 加载状态视图
  Widget _buildLoadingView() {
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
                widget.errorMessage.isNotEmpty ? widget.errorMessage : AppLocalizations.of(context)!.loadingContent(widget.category),
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
  Widget _buildErrorView() {
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
                  AppLocalizations.of(context)!.loadFailed,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.errorMessage,
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
      ),
    );
  }

  // 空状态视图
  Widget _buildEmptyView() {
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
                  AppLocalizations.of(context)!.noContent(widget.category),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.noContentDescription(widget.category),
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
      ),
    );
  }

  // 文章页面视图
  Widget _buildArticlePageView() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (int page) {
        setState(() {
          _currentPage = page;
        });
        print('${widget.category} 页面切换到: $page');
      },
      itemCount: widget.articles.length,
      itemBuilder: (context, index) {
        final article = widget.articles[index];
        
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
                  padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 100.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 正文内容（富文本，不可滚动，固定高度）
                      Expanded(
                        child: Stack(
                          children: [
                            // 内容区域
                            ClipRect(
                              child: FutureBuilder<List<ContentItem>>(
                                future: article.parseContentItems(cacheService: widget.cacheService),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return RichContentWidget(
                                      contentItems: snapshot.data!,
                                      textStyle: TextStyle(
                                        fontSize: 24,
                                        height: 1.6,
                                        color: _textColor,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textColor: _textColor,
                                      enableScrolling: false,
                                      article: article,
                                      contextText: article.content,
                                      cacheService: widget.cacheService,
                                    );
                                  } else {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                },
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
                                    onPressed: () => widget.onShowFullContent(article),
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
                                    label: Text(
                                      AppLocalizations.of(context)!.viewMore,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 来源信息（小号字体）
                Text(
                  AppLocalizations.of(context)!.source(article.source),
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
}
