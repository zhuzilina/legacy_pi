import 'dart:typed_data';

/// 统一的缓存服务，整合AI解读缓存和音频缓存
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
  Map<String, dynamic> getCacheStats() {
    return {
      'aiCacheSize': _aiCache.length,
      'maxAiCacheSize': _maxAiCacheSize,
      'audioCacheSize': _audioCache.length,
      'maxAudioCacheSize': _maxAudioCacheSize,
      'totalCacheSize': _aiCache.length + _audioCache.length,
    };
  }

  /// 清空所有缓存
  void clearAllCache() {
    _aiCache.clear();
    _audioCache.clear();
  }
}
