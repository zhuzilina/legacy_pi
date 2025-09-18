import 'dart:convert';
import 'package:http/http.dart' as http;
import 'unified_cache_service.dart';
import '../config/api_config.dart';

class AiService {
  // 使用统一的API配置
  static String? _baseUrl;
  
  static Future<String> get baseUrl async {
    if (_baseUrl == null) {
      _baseUrl = await ApiConfig.aiInterpretationBaseUrl;
    }
    return _baseUrl!;
  }
  final UnifiedCacheService _cacheService = UnifiedCacheService();
  
  /// 从缓存获取结果
  AiInterpretationResponse? _getFromCache(String text, String promptType, String? customPrompt) {
    final cached = _cacheService.getAiCache(text, promptType, customPrompt);
    
    if (cached != null) {
      print('AI解读缓存命中');
      return cached as AiInterpretationResponse;
    }
    
    print('AI解读缓存未命中');
    return null;
  }
  
  /// 添加到缓存
  void _addToCache(String text, String promptType, String? customPrompt, AiInterpretationResponse response) {
    _cacheService.setAiCache(text, promptType, customPrompt, response);
    print('AI解读结果已缓存');
  }
  
  /// 调用AI解读API（带缓存）
  Future<AiInterpretationResponse?> interpretText({
    required String text,
    String promptType = 'educational',
    String? customPrompt,
    int maxTokens = 2000,
  }) async {
    try {
      // 首先尝试从缓存获取
      final cachedResponse = _getFromCache(text, promptType, customPrompt);
      if (cachedResponse != null) {
        return cachedResponse;
      }
      
      print('AI服务调用 - 文本长度: ${text.length}, 最大tokens: $maxTokens');
      
      final base = await baseUrl;
      final response = await http.post(
        Uri.parse('$base/interpret/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'prompt_type': promptType,
          if (customPrompt != null) 'custom_prompt': customPrompt,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('AI解读API响应成功 - 响应长度: ${response.body.length}');
        final result = AiInterpretationResponse.fromJson(data);
        
        // 如果成功获取结果，添加到缓存
        if (result.success && result.data != null) {
          _addToCache(text, promptType, customPrompt, result);
          print('AI解读结果长度: ${result.data!.interpretation.length}');
        }
        
        return result;
      } else {
        print('AI解读API请求失败: ${response.statusCode}');
        print('响应内容: ${response.body}');
        return null;
      }
    } catch (e) {
      print('AI解读API调用异常: $e');
      return null;
    }
  }
  
  /// 清空缓存
  void clearCache() {
    _cacheService.clearAllCache();
    print('AI解读缓存已清空');
  }
  
  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }
  
  /// 从缓存中移除特定条目
  void removeFromCache(String text, String promptType, String? customPrompt) {
    _cacheService.clearTextCache(text);
    print('AI解读缓存条目已移除');
  }

  /// 总结知识内容
  Future<String> summarizeKnowledge(String content) async {
    try {
      // 首先尝试从缓存获取总结结果
      final cachedResponse = _getFromCache(content, 'knowledge_summary', null);
      if (cachedResponse != null && cachedResponse.data != null) {
        return cachedResponse.data!.interpretation;
      }

      // 没有缓存，调用API进行总结
      final url = Uri.parse('${await baseUrl}/summarize');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': content,
          'prompt_type': 'knowledge_summary',
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final aiResponse = AiInterpretationResponse.fromJson(jsonResponse);

        if (aiResponse.success && aiResponse.data != null) {
          // 将结果添加到缓存
          _addToCache(content, 'knowledge_summary', null, aiResponse);
          return aiResponse.data!.interpretation;
        } else {
          throw Exception(aiResponse.error ?? '总结失败');
        }
      } else {
        throw Exception('网络请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('知识总结失败: $e');
      // 返回默认总结
      return '无法总结内容，请稍后重试。';
    }
  }
}

/// AI解读响应数据模型
class AiInterpretationResponse {
  final bool success;
  final AiInterpretationData? data;
  final String? error;

  AiInterpretationResponse({
    required this.success,
    this.data,
    this.error,
  });

  factory AiInterpretationResponse.fromJson(Map<String, dynamic> json) {
    return AiInterpretationResponse(
      success: json['success'] ?? false,
      data: json['data'] != null 
          ? AiInterpretationData.fromJson(json['data']) 
          : null,
      error: json['error'],
    );
  }
}

/// AI解读数据模型
class AiInterpretationData {
  final String interpretation;
  final String modelUsed;
  final String promptType;
  final int tokensUsed;
  final int originalTextLength;

  AiInterpretationData({
    required this.interpretation,
    required this.modelUsed,
    required this.promptType,
    required this.tokensUsed,
    required this.originalTextLength,
  });

  factory AiInterpretationData.fromJson(Map<String, dynamic> json) {
    return AiInterpretationData(
      interpretation: json['interpretation'] ?? '',
      modelUsed: json['model_used'] ?? '',
      promptType: json['prompt_type'] ?? '',
      tokensUsed: json['tokens_used'] ?? 0,
      originalTextLength: json['original_text_length'] ?? 0,
    );
  }
}
