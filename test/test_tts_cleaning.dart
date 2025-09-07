import '../lib/models/article.dart';

void main() {
  // 测试可能导致"1美元"问题的文本
  final testTexts = [
    "### 一、主要内容和核心观点",
    "## 二、重要论述",
    "# 三、核心要点",
    "1. 第一点内容",
    "2. 第二点内容",
    "一、主要内容",
    "二、核心观点",
    "1美元",
    "100元",
    "宣传思想文化工作的战略定位：习",
  ];
  
  print("=== TTS文本清理测试 ===\n");
  
  for (final text in testTexts) {
    final cleaned = Article.cleanMarkdownForTts(text);
    print("原文: '$text'");
    print("清理后: '$cleaned'");
    print("---");
  }
}
