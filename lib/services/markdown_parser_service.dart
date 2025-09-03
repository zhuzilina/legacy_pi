import 'package:flutter/material.dart';

/// Markdown解析服务，将Markdown格式转换为Flutter文本组件
class MarkdownParserService {
  static final MarkdownParserService _instance = MarkdownParserService._internal();
  factory MarkdownParserService() => _instance;
  MarkdownParserService._internal();

  /// 将Markdown文本解析为Flutter组件列表
  List<Widget> parseMarkdown(String markdown) {
    if (markdown.isEmpty) return [];
    
    final List<Widget> widgets = [];
    final List<String> lines = markdown.split('\n');
    final double verticalSpacing = 16.0; // 定义块级元素之间的垂直间距
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        // 空行添加间距
        if (i < lines.length - 1 && lines[i + 1].trim().isNotEmpty) {
          widgets.add(SizedBox(height: verticalSpacing / 2));
        }
        continue;
      }
      
      // 解析标题
      if (line.startsWith('#')) {
        widgets.add(_parseHeading(line));
        widgets.add(SizedBox(height: verticalSpacing));
        continue;
      }
      
      // 解析项目符号列表
      if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('+ ')) {
        widgets.add(_parseListItem(line));
        widgets.add(SizedBox(height: verticalSpacing / 2));
        continue;
      }
      
      // 解析数字列表
      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        widgets.add(_parseNumberedListItem(line));
        widgets.add(SizedBox(height: verticalSpacing / 2));
        continue;
      }
      
      // 解析引用
      if (line.startsWith('> ')) {
        widgets.add(_parseQuote(line));
        widgets.add(SizedBox(height: verticalSpacing));
        continue;
      }
      
      // 解析代码块
      if (line.startsWith('```')) {
        final codeBlock = _parseCodeBlock(lines, i);
        if (codeBlock != null) {
          widgets.add(codeBlock);
          widgets.add(SizedBox(height: verticalSpacing));
          // 跳过代码块的行
          while (i < lines.length && !lines[i].startsWith('```')) {
            i++;
          }
          continue;
        }
      }
      
      // 解析普通段落
      widgets.add(_parseParagraph(line));
      widgets.add(SizedBox(height: verticalSpacing));
    }
    
    return widgets;
  }

  /// 解析标题
  Widget _parseHeading(String line) {
    int level = 0;
    while (line.startsWith('#')) {
      level++;
      line = line.substring(1);
    }
    
    final text = line.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    
    double fontSize;
    FontWeight fontWeight;
    
    switch (level) {
      case 1:
        fontSize = 24;
        fontWeight = FontWeight.bold;
        break;
      case 2:
        fontSize = 22;
        fontWeight = FontWeight.bold;
        break;
      case 3:
        fontSize = 20;
        fontWeight = FontWeight.w600;
        break;
      case 4:
        fontSize = 18;
        fontWeight = FontWeight.w600;
        break;
      case 5:
        fontSize = 16;
        fontWeight = FontWeight.w500;
        break;
      case 6:
        fontSize = 14;
        fontWeight = FontWeight.w500;
        break;
      default:
        fontSize = 18;
        fontWeight = FontWeight.w600;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.black87,
          height: 1.3,
        ),
      ),
    );
  }

  /// 解析列表项
  Widget _parseListItem(String line) {
    final text = line.substring(2).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: SelectableText.rich(
              _buildTextSpan(text, style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              )),
            ),
          ),
        ],
      ),
    );
  }

  /// 解析数字列表项
  Widget _parseNumberedListItem(String line) {
    final match = RegExp(r'^(\d+)\.\s(.+)$').firstMatch(line);
    if (match == null) return const SizedBox.shrink();
    
    final number = match.group(1)!;
    final text = match.group(2)!.trim();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            child: Text(
              '$number.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText.rich(
              _buildTextSpan(text, style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              )),
            ),
          ),
        ],
      ),
    );
  }

  /// 解析引用
  Widget _parseQuote(String line) {
    final text = line.substring(2).trim();
    if (text.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          left: BorderSide(
            color: Colors.grey[300]!,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText.rich(
        _buildTextSpan(text, style: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: Colors.black87.withOpacity(0.8),
          fontStyle: FontStyle.italic,
        )),
      ),
    );
  }

  /// 解析代码块
  Widget? _parseCodeBlock(List<String> lines, int startIndex) {
    if (startIndex >= lines.length - 1) return null;
    
    final codeLines = <String>[];
    int i = startIndex + 1;
    
    while (i < lines.length && !lines[i].startsWith('```')) {
      codeLines.add(lines[i]);
      i++;
    }
    
    if (codeLines.isEmpty) return null;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: codeLines.map((line) => Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        )).toList(),
      ),
    );
  }

  /// 解析普通段落
  Widget _parseParagraph(String line) {
    return SelectableText.rich(
      _buildTextSpan(line, style: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: Colors.black87,
      )),
      textAlign: TextAlign.start,
    );
  }

  /// 处理行内格式（粗体、斜体、代码等）
  List<Widget> _processInlineFormatting(String text) {
    if (text.isEmpty) return [];
    
    // 使用正则表达式匹配行内格式
    final List<Widget> widgets = [];
    int currentIndex = 0;
    
    // 匹配加粗格式 **text** 或 __text__
    final boldPattern = RegExp(r'\*\*(.*?)\*\*|__(.*?)__');
    final boldMatches = boldPattern.allMatches(text);
    

    
    // 匹配行内代码 `code`
    final codePattern = RegExp(r'`(.*?)`');
    final codeMatches = codePattern.allMatches(text);
    
    // 合并所有匹配项并按位置排序
    final List<_FormatMatch> allMatches = [];
    
    for (final match in boldMatches) {
      allMatches.add(_FormatMatch(
        start: match.start,
        end: match.end,
        type: _FormatType.bold,
        content: match.group(1) ?? match.group(2) ?? '',
      ));
    }
    
    for (final match in codeMatches) {
      allMatches.add(_FormatMatch(
        start: match.start,
        end: match.end,
        type: _FormatType.inlineCode,
        content: match.group(1) ?? '',
      ));
    }
    
    // 按开始位置排序
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    // 构建组件列表
    for (int i = 0; i < allMatches.length; i++) {
      final match = allMatches[i];
      
      // 添加匹配项之前的普通文本
      if (currentIndex < match.start) {
        final plainText = text.substring(currentIndex, match.start);
        if (plainText.isNotEmpty) {
          widgets.add(Text(
            plainText,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ));
        }
      }
      
      // 添加格式化的文本
      widgets.add(_buildFormattedText(match.content, match.type));
      
      currentIndex = match.end;
    }
    
    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      final remainingText = text.substring(currentIndex);
      if (remainingText.isNotEmpty) {
        widgets.add(Text(
          remainingText,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
          ),
        ));
      }
    }
    
    // 如果没有匹配项，返回原始文本
    if (widgets.isEmpty) {
      return [
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
      ];
    }
    
    // 返回行内组件列表
    return widgets;
  }
  
  /// 构建格式化的文本组件
  Widget _buildFormattedText(String text, _FormatType type) {
    switch (type) {
      case _FormatType.bold:
        return Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        );
      case _FormatType.inlineCode:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        );
    }
  }

  /// 构建包含行内加粗格式的 TextSpan
  /// 这是实现富文本效果的核心方法
  TextSpan _buildTextSpan(String text, {TextStyle? style}) {
    final List<TextSpan> children = [];
    // 使用 '**' 作为分隔符来切分字符串
    final List<String> parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      if (part.isEmpty) continue; // 忽略因连续分隔符产生的空字符串

      // 根据部分在数组中的索引奇偶性来判断是否为加粗
      // 索引为奇数的部分是被 '**' 包裹的
      final bool isBold = i % 2 != 0;

      children.add(
        TextSpan(
          text: part,
          // 在基础样式上，如果是加粗部分则覆盖 fontWeight
          style: style?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }

    // 返回一个包含所有子部分的父 TextSpan
    return TextSpan(style: style, children: children);
  }
}

/// 格式匹配项
class _FormatMatch {
  final int start;
  final int end;
  final _FormatType type;
  final String content;
  
  _FormatMatch({
    required this.start,
    required this.end,
    required this.type,
    required this.content,
  });
}

/// 格式类型
enum _FormatType {
  bold,
  inlineCode,
}
