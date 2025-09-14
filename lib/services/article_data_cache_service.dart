import '../models/article.dart';

/// 文章数据缓存项
class ArticleCacheItem {
  final List<Article> articles;
  final DateTime cacheTime;
  final String category;
  final String dataSource; // 'news' 或 'md_docs'

  ArticleCacheItem({
    required this.articles,
    required this.cacheTime,
    required this.category,
    required this.dataSource,
  });

  /// 检查缓存是否过期（10分钟）
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    return difference.inMinutes >= 10;
  }

  /// 获取缓存剩余时间（分钟）
  int get remainingMinutes {
    final now = DateTime.now();
    final difference = now.difference(cacheTime);
    final remaining = 10 - difference.inMinutes;
    return remaining > 0 ? remaining : 0;
  }
}

/// 文章数据缓存服务
class ArticleDataCacheService {
  static final ArticleDataCacheService _instance = ArticleDataCacheService._internal();
  factory ArticleDataCacheService() => _instance;
  ArticleDataCacheService._internal();

  // 缓存存储：分类名 -> 缓存项
  final Map<String, ArticleCacheItem> _cache = {};
  
  // 最大缓存数量
  static const int _maxCacheSize = 20;

  /// 生成缓存键
  String _generateCacheKey(String category, String dataSource) {
    return '${category}_$dataSource';
  }

  /// 获取缓存的文章数据
  List<Article>? getCachedArticles(String category, String dataSource) {
    final cacheKey = _generateCacheKey(category, dataSource);
    final cacheItem = _cache[cacheKey];
    
    if (cacheItem == null) {
      print('缓存未命中: $category ($dataSource)');
      return null;
    }
    
    if (cacheItem.isExpired) {
      print('缓存已过期: $category ($dataSource), 过期时间: ${cacheItem.cacheTime}');
      _cache.remove(cacheKey);
      return null;
    }
    
    print('缓存命中: $category ($dataSource), 剩余时间: ${cacheItem.remainingMinutes}分钟');
    return cacheItem.articles;
  }

  /// 设置缓存的文章数据
  void setCachedArticles(String category, String dataSource, List<Article> articles) {
    final cacheKey = _generateCacheKey(category, dataSource);
    
    // 如果缓存已满，移除最旧的条目
    if (_cache.length >= _maxCacheSize) {
      _removeOldestCache();
    }
    
    final cacheItem = ArticleCacheItem(
      articles: articles,
      cacheTime: DateTime.now(),
      category: category,
      dataSource: dataSource,
    );
    
    _cache[cacheKey] = cacheItem;
    print('缓存已设置: $category ($dataSource), 文章数量: ${articles.length}');
  }

  /// 检查是否有有效的缓存
  bool hasValidCache(String category, String dataSource) {
    final cacheKey = _generateCacheKey(category, dataSource);
    final cacheItem = _cache[cacheKey];
    
    if (cacheItem == null) {
      return false;
    }
    
    if (cacheItem.isExpired) {
      _cache.remove(cacheKey);
      return false;
    }
    
    return true;
  }

  /// 获取缓存信息
  Map<String, dynamic> getCacheInfo(String category, String dataSource) {
    final cacheKey = _generateCacheKey(category, dataSource);
    final cacheItem = _cache[cacheKey];
    
    if (cacheItem == null) {
      return {
        'hasCache': false,
        'isExpired': false,
        'remainingMinutes': 0,
        'articleCount': 0,
        'cacheTime': null,
      };
    }
    
    return {
      'hasCache': true,
      'isExpired': cacheItem.isExpired,
      'remainingMinutes': cacheItem.remainingMinutes,
      'articleCount': cacheItem.articles.length,
      'cacheTime': cacheItem.cacheTime.toIso8601String(),
    };
  }

  /// 清除特定分类的缓存
  void clearCategoryCache(String category, String dataSource) {
    final cacheKey = _generateCacheKey(category, dataSource);
    _cache.remove(cacheKey);
    print('已清除缓存: $category ($dataSource)');
  }

  /// 清除所有缓存
  void clearAllCache() {
    _cache.clear();
    print('已清除所有文章数据缓存');
  }

  /// 移除最旧的缓存项
  void _removeOldestCache() {
    if (_cache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.cacheTime.isBefore(oldestTime)) {
        oldestTime = entry.value.cacheTime;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _cache.remove(oldestKey);
      print('已移除最旧缓存: $oldestKey');
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    int totalArticles = 0;
    int expiredCount = 0;
    int validCount = 0;
    
    for (final cacheItem in _cache.values) {
      totalArticles += cacheItem.articles.length;
      if (cacheItem.isExpired) {
        expiredCount++;
      } else {
        validCount++;
      }
    }
    
    return {
      'totalCacheItems': _cache.length,
      'validCacheItems': validCount,
      'expiredCacheItems': expiredCount,
      'totalArticles': totalArticles,
      'maxCacheSize': _maxCacheSize,
    };
  }

  /// 清理过期的缓存项
  void cleanExpiredCache() {
    final expiredKeys = <String>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('已清理 ${expiredKeys.length} 个过期缓存项');
    }
  }
}
