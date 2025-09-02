// 内容项类型枚举
enum ContentItemType {
  text,    // 纯文本
  image,   // 图片
  imageWithText, // 图片配文字
}

// 内容项模型
class ContentItem {
  final ContentItemType type;
  final String? text;           // 文本内容
  final String? imageUrl;       // 图片URL
  final String? imageAlt;       // 图片alt文本
  final String? imageDescription; // 图片描述文本

  ContentItem({
    required this.type,
    this.text,
    this.imageUrl,
    this.imageAlt,
    this.imageDescription,
  });

  // 创建纯文本内容项
  factory ContentItem.text(String text) {
    return ContentItem(
      type: ContentItemType.text,
      text: text,
    );
  }

  // 创建图片内容项
  factory ContentItem.image(String imageUrl, String imageAlt) {
    return ContentItem(
      type: ContentItemType.image,
      imageUrl: imageUrl,
      imageAlt: imageAlt,
    );
  }

  // 创建图片配文字内容项
  factory ContentItem.imageWithText(
    String imageUrl, 
    String imageAlt, 
    String imageDescription
  ) {
    return ContentItem(
      type: ContentItemType.imageWithText,
      imageUrl: imageUrl,
      imageAlt: imageAlt,
      imageDescription: imageDescription,
    );
  }
}

