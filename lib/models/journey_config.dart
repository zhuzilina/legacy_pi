class JourneyButtonConfig {
  final int id;
  final double yPosition;
  final String imageGroupPath;
  final String activeImageName;
  final int imageGroupId;
  final String description;

  JourneyButtonConfig({
    required this.id,
    required this.yPosition,
    required this.imageGroupPath,
    required this.activeImageName,
    required this.imageGroupId,
    required this.description,
  });

  factory JourneyButtonConfig.fromJson(Map<String, dynamic> json) {
    return JourneyButtonConfig(
      id: json['id'],
      yPosition: json['yPosition'].toDouble(),
      imageGroupPath: json['imageGroupPath'],
      activeImageName: json['activeImageName'],
      imageGroupId: json['imageGroupId'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'yPosition': yPosition,
      'imageGroupPath': imageGroupPath,
      'activeImageName': activeImageName,
      'imageGroupId': imageGroupId,
      'description': description,
    };
  }

  // 获取完整的图片路径
  String get fullImagePath => '$imageGroupPath/$activeImageName';
}

class JourneyConfig {
  final double containerHeight;
  final double buttonSpacing;
  final double buttonMargin;
  final double marginRatio;
  final List<JourneyButtonConfig> buttons;

  JourneyConfig({
    required this.containerHeight,
    required this.buttonSpacing,
    required this.buttonMargin,
    required this.marginRatio,
    required this.buttons,
  });

  factory JourneyConfig.fromJson(Map<String, dynamic> json) {
    return JourneyConfig(
      containerHeight: json['containerHeight'].toDouble(),
      buttonSpacing: json['buttonSpacing'].toDouble(),
      buttonMargin: json['buttonMargin'].toDouble(),
      marginRatio: json['marginRatio'].toDouble(),
      buttons: (json['buttons'] as List)
          .map((buttonJson) => JourneyButtonConfig.fromJson(buttonJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'containerHeight': containerHeight,
      'buttonSpacing': buttonSpacing,
      'buttonMargin': buttonMargin,
      'marginRatio': marginRatio,
      'buttons': buttons.map((button) => button.toJson()).toList(),
    };
  }

  // 根据激活的按钮索引获取对应的图片配置
  List<JourneyButtonConfig> getImagesForActivatedButtons(
    Set<int> activatedIndices,
  ) {
    return activatedIndices
        .where((index) => index < buttons.length)
        .map((index) => buttons[index])
        .toList();
  }

  // 获取指定按钮的配置（通过索引）
  JourneyButtonConfig? getButtonConfig(int buttonIndex) {
    if (buttonIndex >= 0 && buttonIndex < buttons.length) {
      return buttons[buttonIndex];
    }
    return null;
  }

  // 获取指定按钮的配置（通过ID）
  JourneyButtonConfig? getButtonConfigById(int buttonId) {
    try {
      return buttons.firstWhere((button) => button.id == buttonId);
    } catch (e) {
      return null;
    }
  }

  // 计算图片的实际高度（使用原始比例）
  double calculateImageHeight(JourneyButtonConfig config, double screenWidth) {
    // 图片高度将根据原始比例自动计算
    return screenWidth * 0.8; // 默认高度，实际高度将由图片原始比例决定
  }
}

// 图片组管理类
class ImageGroupManager {
  static final ImageGroupManager _instance = ImageGroupManager._internal();
  factory ImageGroupManager() => _instance;
  ImageGroupManager._internal();

  // 存储每个图片组的激活图片
  final Map<int, List<String>> _imageGroups = {};

  // 添加图片到指定组
  void addImageToGroup(int groupId, String imagePath) {
    if (!_imageGroups.containsKey(groupId)) {
      _imageGroups[groupId] = [];
    }

    // 如果图片已存在，先移除（避免重复）
    _imageGroups[groupId]!.remove(imagePath);

    // 添加到列表末尾（最新添加的在最上层）
    _imageGroups[groupId]!.add(imagePath);

    // 不限制图片数量，让图片持续堆叠
  }

  // 获取指定组的所有图片（按显示顺序，最新的在最上层）
  List<String> getGroupImages(int groupId) {
    return _imageGroups[groupId] ?? [];
  }

  // 移除指定组的图片
  void removeImageFromGroup(int groupId, String imagePath) {
    _imageGroups[groupId]?.remove(imagePath);
  }

  // 清空指定组
  void clearGroup(int groupId) {
    _imageGroups.remove(groupId);
  }

  // 获取所有图片组
  Map<int, List<String>> getAllGroups() {
    return Map.from(_imageGroups);
  }
}
