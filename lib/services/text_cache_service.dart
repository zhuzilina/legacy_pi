import '../models/content_item.dart';

/// 文本数据缓存服务，提供文章内容的短期缓存
class TextCacheService {
  static final TextCacheService _instance = TextCacheService._internal();
  factory TextCacheService() => _instance;
  TextCacheService._internal();

  // 文本内容缓存
  final Map<String, List<ContentItem>> _contentCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // 缓存配置
  static const Duration _cacheExpiration = Duration(minutes: 10); // 10分钟过期
  static const int _maxCacheSize = 100; // 最多缓存100篇文章

  /// 生成缓存键
  String _generateCacheKey(String articleId, String content) {
    final contentHash = content.hashCode.toString();
    return 'text_${articleId}_$contentHash';
  }

  /// 获取缓存的文本内容
  List<ContentItem>? getCachedContent(String articleId, String content) {
    final cacheKey = _generateCacheKey(articleId, content);
    final timestamp = _cacheTimestamps[cacheKey];
    
    // 检查是否过期
    if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiration) {
      final cachedContent = _contentCache[cacheKey];
      if (cachedContent != null) {
        print('从缓存获取文本内容: $articleId');
        return cachedContent;
      }
    } else if (timestamp != null) {
      // 过期了，清理缓存
      _contentCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      print('文本缓存已过期，已清理: $articleId');
    }
    
    return null;
  }

  /// 设置文本内容缓存
  void setCachedContent(String articleId, String content, List<ContentItem> contentItems) {
    final cacheKey = _generateCacheKey(articleId, content);
    
    // 如果缓存已满，清理最旧的条目
    if (_contentCache.length >= _maxCacheSize) {
      _cleanOldestCache();
    }
    
    _contentCache[cacheKey] = contentItems;
    _cacheTimestamps[cacheKey] = DateTime.now();
    print('文本内容已缓存: $articleId');
  }

  /// 清理最旧的缓存条目
  void _cleanOldestCache() {
    if (_cacheTimestamps.isEmpty) return;
    
    // 找到最旧的条目
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _contentCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
      print('已清理最旧的文本缓存: $oldestKey');
    }
  }

  /// 清理过期的缓存
  void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) >= _cacheExpiration) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _contentCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('已清理 ${expiredKeys.length} 个过期的文本缓存');
    }
  }

  /// 清理特定文章的缓存
  void clearArticleCache(String articleId) {
    final keysToRemove = _contentCache.keys
        .where((key) => key.contains('text_${articleId}_'))
        .toList();
    
    for (final key in keysToRemove) {
      _contentCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      print('已清理文章缓存: $articleId');
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _contentCache.length,
      'maxCacheSize': _maxCacheSize,
      'cacheExpirationMinutes': _cacheExpiration.inMinutes,
      'oldestCache': _cacheTimestamps.values.isNotEmpty 
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newestCache': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  /// 清空所有文本缓存
  void clearAllCache() {
    _contentCache.clear();
    _cacheTimestamps.clear();
    print('所有文本缓存已清空');
  }
}
