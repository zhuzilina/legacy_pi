import 'content_item.dart';
import '../config/api_config.dart';

class ArticleListResponse {
  final String msg;
  final String crawlDate;
  final int totalArticles;
  final List<String> articleIds;
  final String status;
  final String? taskId;
  final String? message;
  final String? error;

  ArticleListResponse({
    required this.msg,
    required this.crawlDate,
    required this.totalArticles,
    required this.articleIds,
    required this.status,
    this.taskId,
    this.message,
    this.error,
  });

  factory ArticleListResponse.fromJson(Map<String, dynamic> json) {
    return ArticleListResponse(
      msg: json['msg'] ?? '',
      crawlDate: json['crawl_date'] ?? '',
      totalArticles: json['total_articles'] ?? 0,
      articleIds: List<String>.from(json['article_ids'] ?? []),
      status: json['status'] ?? '',
      taskId: json['task_id'],
      message: json['message'],
      error: json['error'],
    );
  }
}

class Article {
  final String id;
  final String title;
  final String source;
  final String publishTime;
  final String category;
  final int wordCount;
  final String originalUrl;
  final String metaInfo;        // 第一个 --- 上方的文档描述信息
  final String content;         // 两个 --- 之间的正文内容
  final String collectTime;

  Article({
    required this.id,
    required this.title,
    required this.source,
    required this.publishTime,
    required this.category,
    required this.wordCount,
    required this.originalUrl,
    required this.metaInfo,
    required this.content,
    required this.collectTime,
  });

  factory Article.fromMarkdown(String id, String markdown) {
    print('开始解析文章 $id，内容长度: ${markdown.length}');
    
    // 按 --- 分隔符分割内容
    final sections = markdown.split('---');
    print('分割后得到 ${sections.length} 个部分');
    
    String title = '';
    String source = '';
    String publishTime = '';
    String category = '';
    int wordCount = 0;
    String originalUrl = '';
    String metaInfo = '';
    String content = '';
    String collectTime = '';

    // 第一部分：文档描述信息（第一个 --- 上方）
    if (sections.isNotEmpty) {
      final firstSection = sections[0].trim();
      print('第一部分（元信息）长度: ${firstSection.length}');
      
      // 从第一部分提取标题和元信息
      final lines = firstSection.split('\n');
      final metaLines = <String>[];
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        
        // 提取标题（第一个 # 开头的行）
        if (trimmedLine.startsWith('# ') && title.isEmpty) {
          title = trimmedLine.substring(2).trim();
          continue;
        }
        
        // 提取结构化元信息
        if (trimmedLine.startsWith('**来源**:')) {
          source = trimmedLine.substring(8).trim();
          metaLines.add(line);
        } else if (trimmedLine.startsWith('**发布时间**:')) {
          publishTime = trimmedLine.substring(10).trim();
          metaLines.add(line);
        } else if (trimmedLine.startsWith('**分类**:')) {
          category = trimmedLine.substring(7).trim();
          metaLines.add(line);
        } else if (trimmedLine.startsWith('**字数**:')) {
          final wordStr = trimmedLine.substring(7).trim();
          wordCount = int.tryParse(wordStr) ?? 0;
          metaLines.add(line);
        } else if (trimmedLine.startsWith('**原文链接**:')) {
          // 提取链接
          final linkMatch = RegExp(r'\[([^\]]+)\]\(([^)]+)\)').firstMatch(trimmedLine);
          if (linkMatch != null) {
            originalUrl = linkMatch.group(2) ?? '';
          }
          metaLines.add(line);
        } else if (trimmedLine.isNotEmpty && !trimmedLine.startsWith('#')) {
          // 其他非空行都加入元信息
          metaLines.add(line);
        }
      }
      
      metaInfo = metaLines.join('\n').trim();
      print('提取的标题: $title');
      print('提取的元信息长度: ${metaInfo.length}');
    }

    // 第二部分：正文内容（两个 --- 之间）
    if (sections.length > 1) {
      content = sections[1].trim();
      print('第二部分（正文）长度: ${content.length}');
      
      // 清理正文内容，移除可能的标题重复
      final contentLines = content.split('\n');
      final cleanContentLines = <String>[];
      
      for (final line in contentLines) {
        final trimmedLine = line.trim();
        // 跳过与标题重复的行
        if (trimmedLine.startsWith('# ') && trimmedLine.substring(2).trim() == title) {
          continue;
        }
        cleanContentLines.add(line);
      }
      
      content = cleanContentLines.join('\n').trim();
      print('清理后的正文长度: ${content.length}');
    }

    // 第三部分：底部信息（第二个 --- 下方，不显示但可以提取采集时间）
    if (sections.length > 2) {
      final thirdSection = sections[2].trim();
      print('第三部分（底部信息）长度: ${thirdSection.length}');
      
      // 从第三部分提取采集时间
      for (final line in thirdSection.split('\n')) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('*采集时间:')) {
          collectTime = trimmedLine.substring(6).replaceAll('*', '').trim();
          break;
        }
      }
    }

    print('文章解析完成: 标题=$title, 元信息长度=${metaInfo.length}, 正文长度=${content.length}');

    return Article(
      id: id,
      title: title,
      source: source,
      publishTime: publishTime,
      category: category,
      wordCount: wordCount,
      originalUrl: originalUrl,
      metaInfo: metaInfo,
      content: content,
      collectTime: collectTime,
    );
  }

  // 获取简短摘要（从正文内容提取）
  String get summary {
    if (content.isEmpty) return '暂无内容';
    
    // 移除 Markdown 标记和图片
    String cleanContent = content
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // 移除图片
        .replaceAll(RegExp(r'#+\s*'), '') // 移除标题标记
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1') // 移除粗体标记
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1') // 移除斜体标记
        .replaceAll(RegExp(r'\n+'), ' ') // 合并换行
        .trim();
    
    // 返回前150个字符作为摘要
    if (cleanContent.length <= 150) {
      return cleanContent;
    } else {
      return '${cleanContent.substring(0, 150)}...';
    }
  }
  
  // 获取格式化的元信息（用于底部覆盖层）
  String get formattedMetaInfo {
    if (metaInfo.isEmpty) return '';
    
    // 简单清理 Markdown 标记
    return metaInfo
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1') // 移除粗体标记
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1') // 移除斜体标记
        .trim();
  }

  // 解析内容为结构化内容项列表
  List<ContentItem> parseContentItems() {
    if (content.isEmpty) return [];
    
    final items = <ContentItem>[];
    final lines = content.split('\n');
    final buffer = StringBuffer();
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // 检查是否是图片行
      final imageMatch = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').firstMatch(line);
      if (imageMatch != null) {
        // 如果缓冲区有文本，先添加文本项
        if (buffer.isNotEmpty) {
          final textContent = buffer.toString().trim();
          if (textContent.isNotEmpty) {
            items.add(ContentItem.text(textContent));
          }
          buffer.clear();
        }
        
        final imageAlt = imageMatch.group(1) ?? '';
        final imageUrl = imageMatch.group(2) ?? '';
        
        // 检查下一行是否是图片描述
        String? imageDescription;
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          // 如果下一行不是空行且不是另一个图片，则认为是图片描述
          if (nextLine.isNotEmpty && 
              !nextLine.startsWith('![') && 
              !nextLine.startsWith('#')) {
            imageDescription = nextLine;
            i++; // 跳过描述行
          }
        }
        
        // 转换图片URL为完整URL
        final fullImageUrl = _convertImageUrl(imageUrl);
        
        if (imageDescription != null && imageDescription.isNotEmpty) {
          items.add(ContentItem.imageWithText(fullImageUrl, imageAlt, imageDescription));
        } else {
          items.add(ContentItem.image(fullImageUrl, imageAlt));
        }
      } else {
        // 普通文本行，添加到缓冲区
        if (line.trim().isNotEmpty || buffer.isNotEmpty) {
          buffer.writeln(line);
        }
      }
    }
    
    // 处理剩余的文本
    if (buffer.isNotEmpty) {
      final textContent = buffer.toString().trim();
      if (textContent.isNotEmpty) {
        items.add(ContentItem.text(textContent));
      }
    }
    
    print('解析完成，共 ${items.length} 个内容项');
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      print('内容项 $i: ${item.type}, 文本长度: ${item.text?.length ?? 0}, 图片: ${item.imageUrl != null}');
    }
    
    return items;
  }
  
  // 转换图片URL为完整URL
  String _convertImageUrl(String originalUrl) {
    // 使用统一的API配置
    final baseUrl = ApiConfig.baseUrl;
    
    // 如果已经是完整URL，直接返回
    if (originalUrl.startsWith('http')) {
      return originalUrl;
    }
    
    // 如果是相对路径，转换为完整URL
    if (originalUrl.startsWith('/api/crawler/image/')) {
      return '$baseUrl$originalUrl';
    }
    
    return originalUrl;
  }
  
  /// 清理Markdown格式标记，返回纯文本
  static String cleanMarkdownForTts(String markdownText) {
    if (markdownText.isEmpty) return '';
    
    String cleanedText = markdownText;
    
    // 移除标题标记
    cleanedText = cleanedText.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    
    // 移除粗体标记
    cleanedText = cleanedText.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    
    // 移除斜体标记
    cleanedText = cleanedText.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    
    // 移除删除线标记
    cleanedText = cleanedText.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
    
    // 移除行内代码标记
    cleanedText = cleanedText.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    
    // 移除代码块标记
    cleanedText = cleanedText.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
    
    // 移除链接标记，保留链接文本
    cleanedText = cleanedText.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    
    // 移除图片标记，保留图片描述
    cleanedText = cleanedText.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (match) {
      final altText = match.group(1) ?? '';
      return altText.isNotEmpty ? '图片：$altText' : '';
    });
    
    // 移除引用标记
    cleanedText = cleanedText.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    
    // 移除列表标记
    cleanedText = cleanedText.replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '');
    cleanedText = cleanedText.replaceAll(RegExp(r'^[\s]*\d+\.\s+', multiLine: true), '');
    
    // 移除任务列表标记
    cleanedText = cleanedText.replaceAll(RegExp(r'^[\s]*[-*+]\s+\[[ xX]\]\s+', multiLine: true), '');
    
    // 移除表格标记
    cleanedText = cleanedText.replaceAll(RegExp(r'^\|.*\|$', multiLine: true), '');
    cleanedText = cleanedText.replaceAll(RegExp(r'^[-|:]+$', multiLine: true), '');
    
    // 移除水平分割线
    cleanedText = cleanedText.replaceAll(RegExp(r'^[-*_]{3,}$', multiLine: true), '');
    
    // 移除HTML标签
    cleanedText = cleanedText.replaceAll(RegExp(r'<[^>]+>'), '');
    
    // 清理多余的空行和空格
    cleanedText = cleanedText
        .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n') // 多个空行变为两个
        .replaceAll(RegExp(r'^\s+', multiLine: true), '') // 行首空格
        .replaceAll(RegExp(r'\s+$', multiLine: true), '') // 行尾空格
        .trim();
    
    // 确保段落之间有适当的间隔
    cleanedText = cleanedText.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    
    return cleanedText;
  }
}
