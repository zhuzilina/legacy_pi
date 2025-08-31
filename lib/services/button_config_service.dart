import 'dart:convert';
import 'package:flutter/services.dart';

class ButtonDescription {
  final int id;
  final String title;
  final String description;

  ButtonDescription({
    required this.id,
    required this.title,
    required this.description,
  });

  factory ButtonDescription.fromJson(Map<String, dynamic> json) {
    return ButtonDescription(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }
}

class ButtonConfigService {
  static final ButtonConfigService _instance = ButtonConfigService._internal();
  factory ButtonConfigService() => _instance;
  ButtonConfigService._internal();

  Map<int, ButtonDescription> _descriptions = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // 加载按钮描述配置
  Future<void> loadConfig() async {
    if (_isLoaded) return;

    try {
      print('开始加载按钮描述配置文件...');
      
      // 从assets加载JSON配置文件
      final jsonString = await rootBundle.loadString(
        'assets/config/button_descriptions.json',
      );
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      final buttonsList = jsonData['buttons'] as List<dynamic>;
      _descriptions.clear();
      
      for (final buttonData in buttonsList) {
        final description = ButtonDescription.fromJson(
          buttonData as Map<String, dynamic>,
        );
        _descriptions[description.id] = description;
      }
      
      _isLoaded = true;
      print('按钮描述配置加载成功，共加载 ${_descriptions.length} 个按钮描述');
    } catch (e) {
      print('加载按钮描述配置失败: $e');
      _createDefaultDescriptions();
    }
  }

  // 创建默认描述（当配置文件加载失败时使用）
  void _createDefaultDescriptions() {
    _descriptions.clear();
    for (int i = 1; i <= 20; i++) {
      _descriptions[i] = ButtonDescription(
        id: i,
        title: '按钮 $i',
        description: '这是第 $i 个按钮的默认描述文本。',
      );
    }
    _isLoaded = true;
    print('使用默认按钮描述配置');
  }

  // 根据按钮ID获取描述
  ButtonDescription? getDescriptionById(int buttonId) {
    if (!_isLoaded) {
      print('配置服务: 配置未加载，无法获取按钮ID $buttonId 的描述');
      return null;
    }
    
    final description = _descriptions[buttonId];
    if (description != null) {
      print('配置服务: 找到按钮ID $buttonId 的描述: ${description.title}');
    } else {
      print('配置服务: 未找到按钮ID $buttonId 的描述');
    }
    return description;
  }

  // 重新加载配置
  Future<void> reloadConfig() async {
    _isLoaded = false;
    _descriptions.clear();
    await loadConfig();
  }
}

