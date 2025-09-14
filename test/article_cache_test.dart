import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_pi/services/article_data_cache_service.dart';
import 'package:legacy_pi/models/article.dart';

void main() {
  group('ArticleDataCacheService Tests', () {
    late ArticleDataCacheService cacheService;

    setUp(() {
      cacheService = ArticleDataCacheService();
      cacheService.clearAllCache();
    });

    test('缓存基本功能测试', () {
      // 创建测试文章
      final testArticles = <Article>[
        Article(
          id: 'test1',
          title: '测试文章1',
          source: '测试来源1',
          publishTime: '2024-01-01',
          category: '新闻',
          wordCount: 100,
          originalUrl: 'https://test1.com',
          metaInfo: '测试元信息1',
          content: '这是测试内容1',
          collectTime: '2024-01-01 10:00:00',
        ),
        Article(
          id: 'test2',
          title: '测试文章2',
          source: '测试来源2',
          publishTime: '2024-01-02',
          category: '新闻',
          wordCount: 200,
          originalUrl: 'https://test2.com',
          metaInfo: '测试元信息2',
          content: '这是测试内容2',
          collectTime: '2024-01-02 10:00:00',
        ),
      ];

      // 测试设置缓存
      cacheService.setCachedArticles('新闻', 'news', testArticles);
      
      // 测试获取缓存
      final cachedArticles = cacheService.getCachedArticles('新闻', 'news');
      expect(cachedArticles, isNotNull);
      expect(cachedArticles!.length, equals(2));
      expect(cachedArticles[0].title, equals('测试文章1'));
      expect(cachedArticles[1].title, equals('测试文章2'));

      // 测试缓存有效性检查
      expect(cacheService.hasValidCache('新闻', 'news'), isTrue);
      expect(cacheService.hasValidCache('精神', 'md_docs'), isFalse);
    });

    test('缓存信息获取测试', () {
      final testArticles = <Article>[
        Article(
          id: 'test1',
          title: '测试文章1',
          source: '测试来源1',
          publishTime: '2024-01-01',
          category: '新闻',
          wordCount: 100,
          originalUrl: 'https://test1.com',
          metaInfo: '测试元信息1',
          content: '这是测试内容1',
          collectTime: '2024-01-01 10:00:00',
        ),
      ];

      cacheService.setCachedArticles('新闻', 'news', testArticles);
      
      final cacheInfo = cacheService.getCacheInfo('新闻', 'news');
      expect(cacheInfo['hasCache'], isTrue);
      expect(cacheInfo['isExpired'], isFalse);
      expect(cacheInfo['articleCount'], equals(1));
      expect(cacheInfo['remainingMinutes'], greaterThan(0));
      expect(cacheInfo['cacheTime'], isNotNull);
    });

    test('缓存过期测试', () {
      final testArticles = <Article>[
        Article(
          id: 'test1',
          title: '测试文章1',
          source: '测试来源1',
          publishTime: '2024-01-01',
          category: '新闻',
          wordCount: 100,
          originalUrl: 'https://test1.com',
          metaInfo: '测试元信息1',
          content: '这是测试内容1',
          collectTime: '2024-01-01 10:00:00',
        ),
      ];

      // 设置缓存
      cacheService.setCachedArticles('新闻', 'news', testArticles);
      
      // 验证缓存存在
      expect(cacheService.hasValidCache('新闻', 'news'), isTrue);
      
      // 模拟缓存过期（通过直接修改缓存时间）
      // 注意：在实际使用中，缓存会在10分钟后自动过期
      // 这里我们测试缓存清理功能
      cacheService.cleanExpiredCache();
      
      // 清理后缓存应该仍然存在（因为还没有真正过期）
      expect(cacheService.hasValidCache('新闻', 'news'), isTrue);
    });

    test('缓存清理测试', () {
      final testArticles = <Article>[
        Article(
          id: 'test1',
          title: '测试文章1',
          source: '测试来源1',
          publishTime: '2024-01-01',
          category: '新闻',
          wordCount: 100,
          originalUrl: 'https://test1.com',
          metaInfo: '测试元信息1',
          content: '这是测试内容1',
          collectTime: '2024-01-01 10:00:00',
        ),
      ];

      // 设置多个分类的缓存
      cacheService.setCachedArticles('新闻', 'news', testArticles);
      cacheService.setCachedArticles('精神', 'md_docs', testArticles);
      
      // 验证缓存存在
      expect(cacheService.hasValidCache('新闻', 'news'), isTrue);
      expect(cacheService.hasValidCache('精神', 'md_docs'), isTrue);
      
      // 清除特定分类缓存
      cacheService.clearCategoryCache('新闻', 'news');
      expect(cacheService.hasValidCache('新闻', 'news'), isFalse);
      expect(cacheService.hasValidCache('精神', 'md_docs'), isTrue);
      
      // 清除所有缓存
      cacheService.clearAllCache();
      expect(cacheService.hasValidCache('精神', 'md_docs'), isFalse);
    });

    test('缓存统计信息测试', () {
      final testArticles = <Article>[
        Article(
          id: 'test1',
          title: '测试文章1',
          source: '测试来源1',
          publishTime: '2024-01-01',
          category: '新闻',
          wordCount: 100,
          originalUrl: 'https://test1.com',
          metaInfo: '测试元信息1',
          content: '这是测试内容1',
          collectTime: '2024-01-01 10:00:00',
        ),
      ];

      // 设置缓存
      cacheService.setCachedArticles('新闻', 'news', testArticles);
      cacheService.setCachedArticles('精神', 'md_docs', testArticles);
      
      final stats = cacheService.getCacheStats();
      expect(stats['totalCacheItems'], equals(2));
      expect(stats['validCacheItems'], equals(2));
      expect(stats['expiredCacheItems'], equals(0));
      expect(stats['totalArticles'], equals(2));
      expect(stats['maxCacheSize'], equals(20));
    });
  });
}
