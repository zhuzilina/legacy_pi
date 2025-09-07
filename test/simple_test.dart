void main() {
  // 测试可能导致问题的正则表达式
  final testText = "### 一、主要内容和核心观点";
  
  print("原文: '$testText'");
  
  // 模拟cleanMarkdownForTts的处理步骤
  String cleanedText = testText;
  
  // 移除标题标记
  cleanedText = cleanedText.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  print("移除标题标记后: '$cleanedText'");
  
  // 测试可能导致问题的正则表达式
  final problematicRegex = RegExp(r'(\d+)([一二三四五六七八九十百千万亿])');
  if (problematicRegex.hasMatch(cleanedText)) {
    print("匹配到问题正则表达式!");
    final match = problematicRegex.firstMatch(cleanedText);
    print("匹配组1: '${match?.group(1)}'");
    print("匹配组2: '${match?.group(2)}'");
  } else {
    print("没有匹配到问题正则表达式");
  }
  
  // 测试其他可能的问题
  final otherRegex = RegExp(r'([a-zA-Z]+)([一-龯])');
  if (otherRegex.hasMatch(cleanedText)) {
    print("匹配到英文字母+中文正则表达式!");
  }
}
