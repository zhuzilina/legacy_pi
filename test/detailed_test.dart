void main() {
  // 测试各种可能导致问题的文本
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
    "1一、主要内容", // 这个可能会被错误匹配
    "2二、核心观点", // 这个可能会被错误匹配
  ];
  
  print("=== 详细TTS文本清理测试 ===\n");
  
  for (final text in testTexts) {
    print("原文: '$text'");
    
    // 模拟cleanMarkdownForTts的处理步骤
    String cleanedText = text;
    
    // 移除标题标记
    cleanedText = cleanedText.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    print("移除标题标记后: '$cleanedText'");
    
    // 测试可能导致问题的正则表达式
    final problematicRegex = RegExp(r'(\d+)([一二三四五六七八九十百千万亿])');
    if (problematicRegex.hasMatch(cleanedText)) {
      print("⚠️  匹配到问题正则表达式!");
      final match = problematicRegex.firstMatch(cleanedText);
      print("匹配组1: '${match?.group(1)}'");
      print("匹配组2: '${match?.group(2)}'");
      
      // 应用这个正则表达式的替换
      final replaced = cleanedText.replaceAllMapped(problematicRegex, (match) {
        final number = match.group(1) ?? '';
        final chinese = match.group(2) ?? '';
        return '$number $chinese';
      });
      print("替换后: '$replaced'");
    } else {
      print("✅ 没有匹配到问题正则表达式");
    }
    
    print("---");
  }
}
