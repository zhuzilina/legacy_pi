import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../pages/chat_page.dart';
import '../models/article.dart';
import '../services/image_cache_service.dart';
import '../services/unified_cache_service.dart';

class RichContentWidget extends StatelessWidget {
  final List<ContentItem> contentItems;
  final TextStyle textStyle;
  final Color textColor;
  final bool enableScrolling; // 是否启用滚动
  final Article? article; // 新增：文章对象，用于传递到聊天页面
  final String? contextText; // 新增：上下文文本，用于传递到聊天页面
  final UnifiedCacheService? cacheService; // 新增：缓存服务

  const RichContentWidget({
    super.key,
    required this.contentItems,
    required this.textStyle,
    required this.textColor,
    this.enableScrolling = true, // 默认启用滚动
    this.article, // 可选的文章对象，用于传递到聊天页面
    this.contextText, // 可选的上下文文本，用于传递到聊天页面
    this.cacheService, // 可选的缓存服务
  });

  @override
  Widget build(BuildContext context) {
    final contentWidgets = contentItems.map((item) => _buildContentItem(item)).toList();
    
    if (enableScrolling) {
      // 启用滚动时，使用 Column
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentWidgets,
      );
    } else {
      // 不启用滚动时，使用 SingleChildScrollView 但限制在父容器内
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(), // 禁用滚动
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets,
        ),
      );
    }
  }

  Widget _buildContentItem(ContentItem item) {
    switch (item.type) {
      case ContentItemType.text:
        return _buildTextItem(item);
      case ContentItemType.image:
        return _buildImageItem(item);
      case ContentItemType.imageWithText:
        return _buildImageWithTextItem(item);
    }
  }

  // 构建纯文本项
  Widget _buildTextItem(ContentItem item) {
    if (item.text == null || item.text!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: _buildSelectableTextWithAiOption(item.text!),
    );
  }

  // 构建图片项
  Widget _buildImageItem(ContentItem item) {
    if (item.imageUrl == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: _buildNetworkImage(item.imageUrl!, item.imageAlt),
    );
  }

  // 构建图片配文字项
  Widget _buildImageWithTextItem(ContentItem item) {
    if (item.imageUrl == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片
          _buildNetworkImage(item.imageUrl!, item.imageAlt),
          const SizedBox(height: 8.0),
          // 图片描述
          if (item.imageDescription != null && item.imageDescription!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: _buildSelectableTextWithAiOption(
                item.imageDescription!,
                customStyle: textStyle.copyWith(
                  fontSize: textStyle.fontSize! * 0.85, // 稍小的字体
                  fontStyle: FontStyle.italic,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 构建网络图片组件（使用缓存）
  Widget _buildNetworkImage(String imageUrl, String? altText) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.fitWidth, // 让图片宽度填满容器，高度按比例缩放
          cacheManager: ImageCacheService().cacheManager, // 使用自定义缓存管理器
          placeholder: (context, url) => Container(
            width: double.infinity,
            height: 200, // 保持固定的加载高度
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  '加载图片中...',
                  style: TextStyle(
                    color: textColor.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          errorWidget: (context, url, error) {
            print('图片加载失败: $imageUrl, 错误: $error');
            return Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: textColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: textColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '图片加载失败',
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  if (altText != null && altText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      altText,
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 构建带有AI选项的可选择文本
  Widget _buildSelectableTextWithAiOption(String text, {TextStyle? customStyle}) {
    final effectiveStyle = customStyle ?? textStyle;
    return Builder(
      builder: (context) => SelectableText(
        text,
        style: effectiveStyle,
        enableInteractiveSelection: true,
        textAlign: TextAlign.start,
        contextMenuBuilder: (context, editableTextState) {
          return AdaptiveTextSelectionToolbar(
            anchors: editableTextState.contextMenuAnchors,
            children: [
              // 默认的复制选项
              Material(
                child: InkWell(
                  onTap: () {
                    editableTextState.cutSelection(SelectionChangedCause.toolbar);
                    editableTextState.hideToolbar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('剪切'),
                  ),
                ),
              ),
              Material(
                child: InkWell(
                  onTap: () {
                    editableTextState.copySelection(SelectionChangedCause.toolbar);
                    editableTextState.hideToolbar();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('复制'),
                  ),
                ),
              ),
              // 新增的"问AI"选项
              if (article != null) // 只有在有文章对象时才显示"问AI"选项
                Material(
                  child: InkWell(
                    onTap: () {
                      editableTextState.hideToolbar();
                      // 获取用户实际选择的文本
                      final selectedText = editableTextState.currentTextEditingValue.selection.textInside(
                        editableTextState.currentTextEditingValue.text,
                      );
                      _navigateToChatWithSelectedText(context, selectedText);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 16),
                          SizedBox(width: 8),
                          Text('问AI'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // 导航到聊天页面，传递选中的文本
  void _navigateToChatWithSelectedText(BuildContext context, String selectedText) {
    if (article == null) return;
    
    // 构建消息参数：选中的文本 + "为我解答"
    final messageParam = '$selectedText为我解答';
    
    // 导航到聊天页面，不传递conversationId，使用默认的对话历史（与直接进入对话相同）
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          article: article!,
          messageParam: messageParam,
          // 不传递conversationId，使用默认的对话历史
        ),
      ),
    );
  }
}
