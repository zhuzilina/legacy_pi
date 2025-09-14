import 'dart:typed_data';
import 'image_cache_service.dart';
import 'text_cache_service.dart';
import 'page_state_cache_service.dart';
import 'article_data_cache_service.dart';
import '../models/article.dart';

/// 统一的缓存服务，整合AI解读缓存、音频缓存、图片缓存、文本缓存和页面状态缓存
class UnifiedCacheService {
  static final UnifiedCacheService _instance = UnifiedCacheService._internal();
  factory UnifiedCacheService() => _instance;
  UnifiedCacheService._internal();

  // AI解读缓存
  final Map<String, dynamic> _aiCache = {};
  static const int _maxAiCacheSize = 50;

  // 音频缓存
  final Map<String, Uint8List> _audioCache = {};
  static const int _maxAudioCacheSize = 30; // 音频文件较大，限制缓存数量

  // 图片缓存服务
  final ImageCacheService _imageCacheService = ImageCacheService();
  
  // 文本缓存服务
  final TextCacheService _textCacheService = TextCacheService();
  
  // 页面状态缓存服务
  final PageStateCacheService _pageStateCacheService = PageStateCacheService();
  
  // 文章数据缓存服务
  final ArticleDataCacheService _articleDataCacheService = ArticleDataCacheService();

  /// 生成AI解读缓存键
  String _generateAiCacheKey(String text, String promptType, String? customPrompt) {
    final textHash = text.hashCode.toString();
    final promptKey = customPrompt ?? promptType;
    return 'ai_${textHash}_${promptKey.hashCode}';
  }

  /// 生成音频缓存键
  String _generateAudioCacheKey(String text, String voice) {
    final textHash = text.hashCode.toString();
    return 'audio_${textHash}_${voice.hashCode}';
  }

  /// 获取AI解读缓存
  dynamic getAiCache(String text, String promptType, String? customPrompt) {
    final cacheKey = _generateAiCacheKey(text, promptType, customPrompt);
    return _aiCache[cacheKey];
  }

  /// 设置AI解读缓存
  void setAiCache(String text, String promptType, String? customPrompt, dynamic response) {
    final cacheKey = _generateAiCacheKey(text, promptType, customPrompt);
    
    // 如果缓存已满，移除最旧的条目
    if (_aiCache.length >= _maxAiCacheSize) {
      final oldestKey = _aiCache.keys.first;
      _aiCache.remove(oldestKey);
    }
    
    _aiCache[cacheKey] = response;
  }

  /// 获取音频缓存
  Uint8List? getAudioCache(String text, String voice) {
    final cacheKey = _generateAudioCacheKey(text, voice);
    return _audioCache[cacheKey];
  }

  /// 设置音频缓存
  void setAudioCache(String text, String voice, Uint8List audioData) {
    final cacheKey = _generateAudioCacheKey(text, voice);
    
    // 如果缓存已满，移除最旧的条目
    if (_audioCache.length >= _maxAudioCacheSize) {
      final oldestKey = _audioCache.keys.first;
      _audioCache.remove(oldestKey);
    }
    
    _audioCache[cacheKey] = audioData;
  }

  /// 检查是否有完整的缓存（AI解读 + 音频）
  bool hasCompleteCache(String text, String promptType, String voice, String? customPrompt) {
    final aiCacheKey = _generateAiCacheKey(text, promptType, customPrompt);
    final audioCacheKey = _generateAudioCacheKey(text, voice);
    
    return _aiCache.containsKey(aiCacheKey) && _audioCache.containsKey(audioCacheKey);
  }

  /// 获取完整的缓存数据
  Map<String, dynamic>? getCompleteCache(String text, String promptType, String voice, String? customPrompt) {
    if (!hasCompleteCache(text, promptType, voice, customPrompt)) {
      return null;
    }
    
    final aiCacheKey = _generateAiCacheKey(text, promptType, customPrompt);
    final audioCacheKey = _generateAudioCacheKey(text, voice);
    
    return {
      'aiResponse': _aiCache[aiCacheKey],
      'audioData': _audioCache[audioCacheKey],
    };
  }

  /// 清除特定文本的所有缓存
  void clearTextCache(String text) {
    final textHash = text.hashCode.toString();
    
    // 清除AI缓存
    final aiKeysToRemove = _aiCache.keys.where((key) => key.contains(textHash)).toList();
    for (final key in aiKeysToRemove) {
      _aiCache.remove(key);
    }
    
    // 清除音频缓存
    final audioKeysToRemove = _audioCache.keys.where((key) => key.contains(textHash)).toList();
    for (final key in audioKeysToRemove) {
      _audioCache.remove(key);
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    final imageStats = await _imageCacheService.getCacheStats();
    final textStats = _textCacheService.getCacheStats();
    final pageStateStats = await _pageStateCacheService.getCacheStats();
    final articleDataStats = _articleDataCacheService.getCacheStats();
    
    return {
      'aiCacheSize': _aiCache.length,
      'maxAiCacheSize': _maxAiCacheSize,
      'audioCacheSize': _audioCache.length,
      'maxAudioCacheSize': _maxAudioCacheSize,
      'imageCacheSize': imageStats['cacheCount'] ?? 0,
      'imageCacheSizeMB': imageStats['cacheSizeMB'] ?? '0.00',
      'textCacheSize': textStats['cacheSize'] ?? 0,
      'maxTextCacheSize': textStats['maxCacheSize'] ?? 0,
      'pageStateCache': pageStateStats,
      'articleDataCache': articleDataStats,
      'totalCacheSize': _aiCache.length + _audioCache.length + 
                       (imageStats['cacheCount'] ?? 0) + 
                       (textStats['cacheSize'] ?? 0) +
                       (articleDataStats['totalCacheItems'] ?? 0),
    };
  }

  /// 清空所有缓存
  Future<void> clearAllCache() async {
    _aiCache.clear();
    _audioCache.clear();
    await _imageCacheService.clearAllCache();
    _textCacheService.clearAllCache();
    await _pageStateCacheService.clearAllPageState();
    _articleDataCacheService.clearAllCache();
  }

  /// 预加载文章中的图片
  Future<void> preloadArticleImages(List<String> imageUrls) async {
    await _imageCacheService.preloadImages(imageUrls);
  }

  /// 获取图片缓存服务
  ImageCacheService get imageCacheService => _imageCacheService;
  
  /// 获取文本缓存服务
  TextCacheService get textCacheService => _textCacheService;
  
  /// 获取页面状态缓存服务
  PageStateCacheService get pageStateCacheService => _pageStateCacheService;
  
  /// 获取文章数据缓存服务
  ArticleDataCacheService get articleDataCacheService => _articleDataCacheService;
  
  // ========== 文章数据缓存相关方法 ==========
  
  /// 获取缓存的文章数据
  List<Article>? getCachedArticles(String category, String dataSource) {
    return _articleDataCacheService.getCachedArticles(category, dataSource);
  }
  
  /// 设置缓存的文章数据
  void setCachedArticles(String category, String dataSource, List<Article> articles) {
    _articleDataCacheService.setCachedArticles(category, dataSource, articles);
  }
  
  /// 检查是否有有效的文章缓存
  bool hasValidArticleCache(String category, String dataSource) {
    return _articleDataCacheService.hasValidCache(category, dataSource);
  }
  
  /// 获取文章缓存信息
  Map<String, dynamic> getArticleCacheInfo(String category, String dataSource) {
    return _articleDataCacheService.getCacheInfo(category, dataSource);
  }
  
  /// 清除特定分类的文章缓存
  void clearCategoryArticleCache(String category, String dataSource) {
    _articleDataCacheService.clearCategoryCache(category, dataSource);
  }
  
  /// 清理过期的文章缓存
  void cleanExpiredArticleCache() {
    _articleDataCacheService.cleanExpiredCache();
  }
  
  /// 清理所有文章数据缓存（应用启动时使用）
  void clearAllArticleCache() {
    _articleDataCacheService.clearAllCache();
    print('已清理所有文章数据缓存');
  }
}
