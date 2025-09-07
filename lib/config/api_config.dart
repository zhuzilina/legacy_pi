import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// API配置类，从配置文件动态加载API地址
class ApiConfig {
  static Map<String, dynamic>? _config;
  static bool _isInitialized = false;

  /// 初始化配置
  static Future<void> _initializeConfig() async {
    if (_isInitialized) return;
    
    try {
      // 尝试加载配置文件
      final configString = await rootBundle.loadString('lib/config/app_config.json');
      _config = json.decode(configString);
      _isInitialized = true;
      
      if (kDebugMode) {
        print('配置文件加载成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('配置文件加载失败，使用默认配置: $e');
      }
      // 如果配置文件加载失败，使用默认配置
      _config = {
        'api': {
          'baseUrl': kIsWeb ? 'http://localhost:8000' : 'http://121.36.87.174',
          'endpoints': {
            'aiChat': '/api/ai-chat',
            'aiInterpretation': '/api/ai',
            'mdDocs': '/api/md-docs',
            'knowledgeQuiz': '/api/knowledge-quiz',
            'tts': '/api/tts',
            'crawler': '/api/crawler'
          }
        }
      };
      _isInitialized = true;
    }
  }

  /// 获取基础API地址
  static Future<String> get baseUrl async {
    await _initializeConfig();
    final apiConfig = _config!['api'] as Map<String, dynamic>;
    final baseUrl = apiConfig['baseUrl'] as String;
    final port = apiConfig['port'] as String?;
    
    if (port != null && port.isNotEmpty) {
      return '$baseUrl:$port';
    }
    return baseUrl;
  }
  
  /// 获取TTS API地址
  static Future<String> get ttsBaseUrl async {
    final base = await baseUrl;
    final endpoints = _config!['api']['endpoints'] as Map<String, dynamic>;
    return '$base${endpoints['tts']}';
  }
  
  /// 获取AI对话API地址
  static Future<String> get aiChatBaseUrl async {
    final base = await baseUrl;
    final endpoints = _config!['api']['endpoints'] as Map<String, dynamic>;
    return '$base${endpoints['aiChat']}';
  }
  /// 获取AI解读API地址
  static Future<String> get aiInterpretationBaseUrl async {
    final base = await baseUrl;
    final endpoints = _config!['api']['endpoints'] as Map<String, dynamic>;
    return '$base${endpoints['aiInterpretation']}';
  }
  /// 获取MD文档API地址
  static Future<String> get mdDocsBaseUrl async {
    final base = await baseUrl;
    final endpoints = _config!['api']['endpoints'] as Map<String, dynamic>;
    return '$base${endpoints['mdDocs']}';
  }
  
  /// 获取知识问答API地址
  static Future<String> get knowledgeQuizBaseUrl async {
    final base = await baseUrl;
    final endpoints = _config!['api']['endpoints'] as Map<String, dynamic>;
    return '$base${endpoints['knowledgeQuiz']}';
  }
  
  /// 获取新闻爬虫API地址
  static Future<String> get crawlerBaseUrl async {
    final base = await baseUrl;
    final endpoints = _config!['api']['endpoints'] as Map<String, dynamic>;
    return '$base${endpoints['crawler']}';
  }
  
  /// 获取当前平台信息
  static Future<String> get platformInfo async {
    await _initializeConfig();
    final base = await baseUrl;
    if (kIsWeb) {
      return 'Web环境 - 使用 $base';
    } else {
      return '移动端环境 - 使用 $base';
    }
  }
  
  /// 调试信息
  static Future<void> printConfig() async {
    if (kDebugMode) {
      await _initializeConfig();
      print('=== API配置信息 ===');
      print('当前平台: ${kIsWeb ? "Web" : "移动端"}');
      print('基础地址: ${await baseUrl}');
      print('TTS地址: ${await ttsBaseUrl}');
      print('AI对话地址: ${await aiChatBaseUrl}');
      print('AI解读地址: ${await aiInterpretationBaseUrl}');
      print('MD文档地址: ${await mdDocsBaseUrl}');
      print('知识问答地址: ${await knowledgeQuizBaseUrl}');
      print('爬虫地址: ${await crawlerBaseUrl}');
      print('==================');
    }
  }
}

