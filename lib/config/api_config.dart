import 'package:flutter/foundation.dart';

/// API配置类，根据平台动态选择API地址
class ApiConfig {
  /// 获取基础API地址
  static String get baseUrl {
    if (kIsWeb) {
      // Web环境使用localhost
      return 'http://localhost:8000';
    } else {
      // 移动端环境使用宿主机IP地址
      // Android Studio模拟器使用10.0.2.2访问宿主机
      // 真机需要根据实际网络环境修改为宿主机IP
      return 'http://10.0.2.2:8000';
    }
  }
  
  /// 获取TTS API地址
  static String get ttsBaseUrl => '$baseUrl/api/tts';
  
  /// 获取AI解读API地址
  static String get aiBaseUrl => '$baseUrl/api/ai';
  
  /// 获取新闻爬虫API地址
  static String get crawlerBaseUrl => '$baseUrl/api/crawler';
  
  /// 获取当前平台信息
  static String get platformInfo {
    if (kIsWeb) {
      return 'Web环境 - 使用localhost:8000';
    } else {
      return '移动端环境 - 使用10.0.2.2:8000 (Android模拟器宿主机)';
    }
  }
  
  /// 调试信息
  static void printConfig() {
    if (kDebugMode) {
      print('=== API配置信息 ===');
      print('当前平台: ${kIsWeb ? "Web" : "移动端"}');
      print('基础地址: $baseUrl');
      print('TTS地址: $ttsBaseUrl');
      print('AI地址: $aiBaseUrl');
      print('爬虫地址: $crawlerBaseUrl');
      print('==================');
    }
  }
}

