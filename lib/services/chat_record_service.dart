import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/chat_record.dart';
import '../models/article.dart';

class ChatRecordService {
  static const String _chatRecordsKey = 'chat_records';
  static const String _chatDataPrefix = 'chat_';
  
  // 获取所有聊天记录
  static Future<List<ChatRecord>> getAllChatRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getString(_chatRecordsKey);
      
      if (recordsJson == null) return [];
      
      final List<dynamic> recordsList = jsonDecode(recordsJson);
      return recordsList.map((json) => ChatRecord.fromJson(json)).toList();
    } catch (e) {
      print('获取聊天记录失败: $e');
      return [];
    }
  }
  
  // 保存聊天记录
  static Future<void> saveChatRecord(Article article, List<Map<String, String>> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 创建聊天记录
      final chatRecord = ChatRecord(
        title: article.title,
        content: article.content,
        lastUpdated: DateTime.now(),
        messageCount: messages.length,
        chatKey: '${_chatDataPrefix}${article.title.hashCode}',
      );
      
      // 获取现有记录
      final existingRecords = await getAllChatRecords();
      
      // 查找是否已存在相同标题的记录
      final existingIndex = existingRecords.indexWhere((record) => record.title == article.title);
      
      if (existingIndex != -1) {
        // 更新现有记录
        existingRecords[existingIndex] = chatRecord;
      } else {
        // 添加新记录
        existingRecords.add(chatRecord);
      }
      
      // 按最后更新时间排序，最新的在前面
      existingRecords.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      
      // 保存到本地
      await prefs.setString(_chatRecordsKey, jsonEncode(
        existingRecords.map((record) => record.toJson()).toList()
      ));
      
      print('聊天记录已保存: ${article.title}');
    } catch (e) {
      print('保存聊天记录失败: $e');
    }
  }
  
  // 删除聊天记录
  static Future<void> deleteChatRecord(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有记录
      final existingRecords = await getAllChatRecords();
      
      // 移除指定标题的记录
      existingRecords.removeWhere((record) => record.title == title);
      
      // 保存更新后的记录
      await prefs.setString(_chatRecordsKey, jsonEncode(
        existingRecords.map((record) => record.toJson()).toList()
      ));
      
      // 删除对应的聊天数据
      final chatKey = '${_chatDataPrefix}${title.hashCode}';
      await prefs.remove(chatKey);
      
      print('聊天记录已删除: $title');
    } catch (e) {
      print('删除聊天记录失败: $e');
    }
  }
  
  // 清空所有聊天记录
  static Future<void> clearAllChatRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取所有聊天记录
      final records = await getAllChatRecords();
      
      // 删除所有聊天数据
      for (final record in records) {
        await prefs.remove(record.chatKey);
      }
      
      // 清空记录列表
      await prefs.remove(_chatRecordsKey);
      
      print('所有聊天记录已清空');
    } catch (e) {
      print('清空聊天记录失败: $e');
    }
  }
  
  // 获取指定文章的聊天消息
  static Future<List<Map<String, String>>> getChatMessages(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatKey = '${_chatDataPrefix}${title.hashCode}';
      
      final chatData = prefs.getString(chatKey);
      if (chatData != null) {
        final List<dynamic> messagesList = jsonDecode(chatData);
        return messagesList.map((item) => <String, String>{
          'text': item['text'] ?? '',
          'sender': item['sender'] ?? '',
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('获取聊天消息失败: $e');
      return [];
    }
  }
  
  // 检查是否有聊天记录
  static Future<bool> hasChatRecords() async {
    final records = await getAllChatRecords();
    return records.isNotEmpty;
  }
}
