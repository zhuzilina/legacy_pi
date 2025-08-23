import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/journey_config.dart';

class JourneyConfigService {
  static final JourneyConfigService _instance =
      JourneyConfigService._internal();
  factory JourneyConfigService() => _instance;
  JourneyConfigService._internal();

  JourneyConfig? _config;
  bool _isLoaded = false;

  // 获取配置实例
  JourneyConfig get config {
    if (_config == null) {
      throw StateError('JourneyConfig not loaded. Call loadConfig() first.');
    }
    return _config!;
  }

  // 检查是否已加载
  bool get isLoaded => _isLoaded;

  // 加载配置文件
  Future<void> loadConfig() async {
    if (_isLoaded) return;

    try {
      print('开始加载journey配置文件...');

      // 从assets加载JSON配置文件
      final jsonString = await rootBundle.loadString(
        'assets/config/journey_config.json',
      );
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      _config = JourneyConfig.fromJson(jsonData);
      _isLoaded = true;

      print('journey配置文件加载成功，包含 ${_config!.buttons.length} 个按钮配置');
      print('可用的按钮配置ID: ${_config!.buttons.map((btn) => btn.id).join(', ')}');
    } catch (e) {
      print('加载journey配置文件失败: $e');
      // 使用默认配置
      _createDefaultConfig();
    }
  }

  // 创建默认配置（当配置文件加载失败时使用）
  void _createDefaultConfig() {
    _config = JourneyConfig(
      containerHeight: 11500,
      buttonSpacing: 115,
      buttonMargin: 50,
      marginRatio: 0.25,
      buttons: [
        JourneyButtonConfig(
          id: 1,
          yPosition: 11675,
          imageGroupPath: 'assets/images/journey/img1',
          activeImageName: 'D.png',
          imageGroupId: 1,
          description: '第一个里程碑',
        ),
        JourneyButtonConfig(
          id: 2,
          yPosition: 11560,
          imageGroupPath: 'assets/images/journey/img2',
          activeImageName: 'C.png',
          imageGroupId: 2,
          description: '第二个里程碑',
        ),
      ],
    );
    _isLoaded = true;
    print('使用默认journey配置');
  }

  // 重新加载配置
  Future<void> reloadConfig() async {
    _isLoaded = false;
    _config = null;
    await loadConfig();
  }

  // 获取激活的图片配置
  List<JourneyButtonConfig> getActiveImages(Set<int> activatedIndices) {
    if (!_isLoaded) return [];
    return _config!.getImagesForActivatedButtons(activatedIndices);
  }

  // 获取指定按钮的配置
  JourneyButtonConfig? getButtonConfig(int buttonIndex) {
    if (!_isLoaded) return null;
    return _config!.getButtonConfig(buttonIndex);
  }

  // 获取指定按钮的配置（通过ID）
  JourneyButtonConfig? getButtonConfigById(int buttonId) {
    if (!_isLoaded) {
      print('配置服务: 配置未加载，无法获取按钮ID $buttonId 的配置');
      return null;
    }
    final config = _config!.getButtonConfigById(buttonId);
    print('配置服务: 查找按钮ID $buttonId, 结果: ${config != null ? '找到配置' : '未找到配置'}');
    if (config != null) {
      print('配置服务: 按钮 $buttonId 配置详情: ${config.fullImagePath}');
    }
    return config;
  }

  // 计算图片高度（使用原始比例）
  double calculateImageHeight(JourneyButtonConfig config, double screenWidth) {
    // 图片高度将根据原始比例自动计算
    return screenWidth * 0.75; // 使用4:3比例作为默认
  }

  // 获取容器高度
  double get containerHeight {
    if (!_isLoaded) return 11500; // 默认高度
    return _config!.containerHeight;
  }

  // 获取按钮间距
  double get buttonSpacing {
    if (!_isLoaded) return 115; // 默认间距
    return _config!.buttonSpacing;
  }

  // 获取按钮边距
  double get buttonMargin {
    if (!_isLoaded) return 50; // 默认边距
    return _config!.buttonMargin;
  }

  // 获取边距比例
  double get marginRatio {
    if (!_isLoaded) return 0.25; // 默认比例
    return _config!.marginRatio;
  }
}
