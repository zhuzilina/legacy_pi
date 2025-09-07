class ChatRecord {
  final String title; // 文章标题
  final String content; // 文章内容
  final DateTime lastUpdated; // 最后更新时间
  final int messageCount; // 消息数量
  final String chatKey; // 聊天记录的唯一键

  ChatRecord({
    required this.title,
    required this.content,
    required this.lastUpdated,
    required this.messageCount,
    required this.chatKey,
  });

  // 从JSON创建ChatRecord对象
  factory ChatRecord.fromJson(Map<String, dynamic> json) {
    return ChatRecord(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? DateTime.now().toIso8601String()),
      messageCount: json['messageCount'] ?? 0,
      chatKey: json['chatKey'] ?? '',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'lastUpdated': lastUpdated.toIso8601String(),
      'messageCount': messageCount,
      'chatKey': chatKey,
    };
  }

  // 创建ChatRecord的副本，更新某些字段
  ChatRecord copyWith({
    String? title,
    String? content,
    DateTime? lastUpdated,
    int? messageCount,
    String? chatKey,
  }) {
    return ChatRecord(
      title: title ?? this.title,
      content: content ?? this.content,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      messageCount: messageCount ?? this.messageCount,
      chatKey: chatKey ?? this.chatKey,
    );
  }

  @override
  String toString() {
    return 'ChatRecord(title: $title, lastUpdated: $lastUpdated, messageCount: $messageCount)';
  }
}



