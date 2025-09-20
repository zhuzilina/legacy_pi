import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../services/md_docs_api_service.dart';
import '../../../models/article.dart';
import '../../../models/content_item.dart';
import '../../../config/api_config.dart';
import '../../../widgets/rich_content_widget.dart';
import '../../../services/unified_cache_service.dart';
import '../../../l10n/app_localizations.dart';

class ScenicAttractionCard extends StatefulWidget {
  const ScenicAttractionCard({super.key});

  @override
  State<ScenicAttractionCard> createState() => _ScenicAttractionCardState();
}

class _ScenicAttractionCardState extends State<ScenicAttractionCard> {
  final MdDocsApiService _mdDocsApiService = MdDocsApiService();
  final UnifiedCacheService _cacheService = UnifiedCacheService();

  List<Map<String, dynamic>> _attractions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // 网络图片配置
  final List<String> _coverImages = [
    'http://pic.people.com.cn/mediafile/pic/BIG/20230519/5/12397810148944316541.jpg',
    'https://www.zunyihy.cn/n342/20220411/880/material/2f7caa1a-4c05-43c3-8482-461108fd9a40.jpg',
    'http://www.luxunmuseum.com.cn/data/attached/4b5ce2fe28308fd9/image/20250415/17447007818454.jpg',
    'http://ent.people.com.cn/mediafile/pic/20230630/44/16721425811386333008.jpg',
    'http://pic.people.com.cn/NMediaFile/2025/0730/MAIN1753860241007TT9P3PTHQ0.jpg',
    'http://dangshi.people.com.cn/NMediaFile/2021/0316/MAIN202103161531589346569752066.jpg',
    'http://dangshi.people.com.cn/NMediaFile/2021/0316/MAIN202103161436140297755572336.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadScenicAttractions();
  }

  // 加载景点数据
  Future<void> _loadScenicAttractions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 获取 scenic 分类下的文档ID列表
      final response = await _mdDocsApiService.getDocumentIdsByCategory(
        category: 'scenic',
      );

      if (response == null || response.articleIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '暂无景点数据';
        });
        return;
      }

      // 限制最多获取10个景点
      final targetIds = response.articleIds.take(10).toList();
      final articles = await _mdDocsApiService.getMultipleDocuments(targetIds);

      // 处理文章数据，提取 meta 信息和首图
      final List<Map<String, dynamic>> attractions = [];
      for (int i = 0; i < articles.length; i++) {
        final attraction = await _processArticleToAttraction(articles[i], i);
        if (attraction != null) {
          attractions.add(attraction);
        }
      }

      setState(() {
        _attractions = attractions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载景点数据时发生错误: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '加载景点数据失败';
      });
    }
  }

  // 处理文章数据为景点信息
  Future<Map<String, dynamic>?> _processArticleToAttraction(Article article, int index) async {
    try {
      // 解析 meta 信息，格式如: - meta:[贵州省遵义市红花岗区子尹路96号][4.9][8900]
      final location = _extractMetaInfo(article.content, r'meta:\[([^\]]+)\]');
      final rating = _extractMetaInfo(article.content, r'meta:\[[^\]]+\]\[([^\]]+)\]');
      final visitors = _extractMetaInfo(article.content, r'meta:\[[^\]]+\]\[[^\]]+\]\[([^\]]+)\]');

      // 使用预设的网络图片作为封面，而不是从文章中提取
      final coverImage = _coverImages[index % _coverImages.length];

      final result = {
        'id': article.id,
        'title': article.title,
        'description': _generateDescription(article.content),
        'location': location.isNotEmpty ? location : '位置信息暂无',
        'rating': rating.isNotEmpty ? double.tryParse(rating) ?? 4.5 : 4.5,
        'visitors': visitors.isNotEmpty ? int.tryParse(visitors) ?? 0 : 0,
        'image': coverImage, // 使用网络图片作为封面
        'article': article,
      };
      return result;
    } catch (e) {
      debugPrint('_processArticleToAttraction 方法执行出错: $e');
      return null;
    }
  }

  // 提取 meta 信息
  String _extractMetaInfo(String content, String pattern) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(content);
    return match?.group(1) ?? '';
  }

  // 清理内容，移除meta信息行
  String _cleanContent(String content) {
    // 移除 meta 信息行（格式如: - meta:[贵州省遵义市红花岗区子尹路96号][4.9][8900]）
    // 使用多行模式，匹配任意位置的 meta 行
    final cleanContent = content.replaceAll(RegExp(r'^.*?- *meta:\[.*?\].*$', multiLine: true), '').trim();
    return cleanContent;
  }

  // 生成描述
  String _generateDescription(String content) {
    // 移除 meta 信息行
    final cleanContent = _cleanContent(content);

    // 移除markdown图片语法 ![alt](url)
    final noImagesContent = cleanContent.replaceAll(RegExp(r'!\[.*?]\([^)]+\)'), '').trim();

    // 取前100个字符作为描述
    if (noImagesContent.length > 100) {
      return '${noImagesContent.substring(0, 100)}...';
    }
    return noImagesContent;
  }

  // 点击景点卡片
  void _onAttractionTapped(Map<String, dynamic> attraction) {
    final article = attraction['article'] as Article;
    _showAttractionDetails(context, article, attraction);
  }

  // 显示景点详情
  void _showAttractionDetails(BuildContext context, Article article, Map<String, dynamic> attraction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Expanded(
                    child: Text(
                      attraction['title'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 景点信息
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.red[600], size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      attraction['location'],
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.star, color: Colors.orange[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${attraction['rating']}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.people, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${attraction['visitors']}人参观',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 内容 - 使用富文本组件解析markdown（已移除meta信息）
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: FutureBuilder<List<ContentItem>>(
                    future: () async {
                      // 创建一个临时的Article对象，内容已清理
                      final cleanedArticle = Article(
                        id: article.id,
                        title: article.title,
                        source: article.source,
                        publishTime: article.publishTime,
                        category: article.category,
                        wordCount: article.wordCount,
                        originalUrl: article.originalUrl,
                        metaInfo: article.metaInfo,
                        content: _cleanContent(article.content),
                        collectTime: article.collectTime,
                      );
                      return await cleanedArticle.parseContentItems(cacheService: _cacheService);
                    }(),
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
                          enableScrolling: false,
                          article: article,
                          contextText: _cleanContent(article.content),
                          cacheService: _cacheService,
                        );
                      } else if (snapshot.hasError) {
                        return Text(
                          '加载内容失败',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        );
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadScenicAttractions,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attractions.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) => _buildAttractionCard(_attractions[index]),
                ),
    );
  }

  Widget _buildAttractionCard(Map<String, dynamic> attraction) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 景点图片
            Image.network(
              attraction['image'],
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.landscape,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),

            // 底部信息渐变层
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 景点名称
                    Text(
                      attraction['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 位置信息
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white70, size: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            attraction['location'],
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 评分和访问量
                    Row(
                      children: [
                        // 评分
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.orange[300], size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${attraction['rating']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // 访问量
                        Row(
                          children: [
                            Icon(Icons.people, color: Colors.blue[300], size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${attraction['visitors']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).tap(() {
      _onAttractionTapped(attraction);
    });
  }
}

// 扩展 Widget 添加 tap 方法
extension WidgetExtension on Widget {
  Widget tap(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: this,
    );
  }
}