import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/user_score.dart';

/// 兑换商品数据模型
class RewardItem {
  final String title;
  final String cover;
  final int points;

  RewardItem({
    required this.title,
    required this.cover,
    required this.points,
  });

  factory RewardItem.fromJson(Map<String, dynamic> json) {
    return RewardItem(
      title: json['title'] ?? '',
      cover: json['cover'] ?? '',
      points: json['points'] ?? 0,
    );
  }
}

/// 兑换记录数据模型
class RewardRecord {
  final int id;
  final String itemName;
  final String itemCover;
  final int points;
  final DateTime redeemedAt;
  final String status; // pending, completed, cancelled

  RewardRecord({
    required this.id,
    required this.itemName,
    required this.itemCover,
    required this.points,
    required this.redeemedAt,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'itemCover': itemCover,
      'points': points,
      'redeemedAt': redeemedAt.millisecondsSinceEpoch,
      'status': status,
    };
  }

  factory RewardRecord.fromJson(Map<String, dynamic> json) {
    return RewardRecord(
      id: json['id'] ?? 0,
      itemName: json['itemName'] ?? '',
      itemCover: json['itemCover'] ?? '',
      points: json['points'] ?? 0,
      redeemedAt: json['redeemedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['redeemedAt'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }
}

/// 兑换服务
class RewardService {
  static const String _rewardRecordsKey = 'reward_records';
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// 获取可兑换商品列表
  static Future<List<RewardItem>> getRewardItems() async {
    try {
      final String response = await rootBundle.loadString('assets/config/reward.json');
      final List<dynamic> data = await json.decode(response);
      return data.map((item) => RewardItem.fromJson(item)).toList();
    } catch (e) {
      print('加载兑换商品失败: $e');
      return [];
    }
  }

  /// 获取用户兑换记录
  Future<List<RewardRecord>> getRewardRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getString(_rewardRecordsKey);

      if (recordsJson == null) {
        return [];
      }

      final List<dynamic> decoded = json.decode(recordsJson);
      return decoded.map((item) => RewardRecord.fromJson(item)).toList();
    } catch (e) {
      print('获取兑换记录失败: $e');
      return [];
    }
  }

  /// 兑换商品
  Future<bool> redeemReward({
    required User user,
    required RewardItem item,
  }) async {
    try {
      // 检查用户积分是否足够
      final userPoints = await _databaseHelper.getTotalUserScore(user.id!);
      if (userPoints < item.points) {
        return false;
      }

      // 扣除积分
      await _databaseHelper.insertUserScore(
        UserScore(
          userId: user.id!,
          score: -item.points,
          description: '兑换商品: ${item.title}',
          earnedAt: DateTime.now(),
        ),
      );

      // 添加兑换记录
      final records = await getRewardRecords();
      final newRecord = RewardRecord(
        id: records.length + 1,
        itemName: item.title,
        itemCover: item.cover,
        points: item.points,
        redeemedAt: DateTime.now(),
        status: 'pending',
      );

      records.add(newRecord);

      // 保存兑换记录
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = json.encode(records.map((r) => r.toJson()).toList());
      await prefs.setString(_rewardRecordsKey, recordsJson);

      print('兑换成功: ${item.title}, 扣除${item.points}积分');
      return true;
    } catch (e) {
      print('兑换失败: $e');
      return false;
    }
  }

  /// 获取兑换统计
  Future<Map<String, dynamic>> getRedeemStats() async {
    try {
      final records = await getRewardRecords();
      final totalSpent = records.fold(0, (sum, record) => sum + record.points);
      final totalItems = records.length;
      final pendingCount = records.where((r) => r.status == 'pending').length;
      final completedCount = records.where((r) => r.status == 'completed').length;

      return {
        'totalSpent': totalSpent,
        'totalItems': totalItems,
        'pendingCount': pendingCount,
        'completedCount': completedCount,
      };
    } catch (e) {
      print('获取兑换统计失败: $e');
      return {
        'totalSpent': 0,
        'totalItems': 0,
        'pendingCount': 0,
        'completedCount': 0,
      };
    }
  }
}