import 'package:flutter/material.dart';
import '../services/reward_service.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final RewardService _rewardService = RewardService();
  User? _currentUser;
  int _totalScore = 0;
  List<RewardItem> _rewardItems = [];
  List<RewardRecord> _rewardRecords = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取默认用户
      _currentUser = await _databaseHelper.getUserByUsername('default_user');

      if (_currentUser != null) {
        // 加载积分数据
        _totalScore = await _databaseHelper.getTotalUserScore(_currentUser!.id!);

        // 并行加载兑换商品和记录
        final itemsFuture = RewardService.getRewardItems();
        final recordsFuture = _rewardService.getRewardRecords();
        final statsFuture = _rewardService.getRedeemStats();

        final results = await Future.wait([itemsFuture, recordsFuture, statsFuture]);

        setState(() {
          _rewardItems = results[0] as List<RewardItem>;
          _rewardRecords = results[1] as List<RewardRecord>;
          _stats = results[2] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载数据失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _redeemItem(RewardItem item) async {
    if (_currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认兑换'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('商品：${item.title}'),
            Text('所需积分：${item.points}'),
            Text('当前积分：$_totalScore'),
            const SizedBox(height: 8),
            if (_totalScore < item.points)
              Text(
                '积分不足！',
                style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('确认兑换'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _rewardService.redeemReward(
        user: _currentUser!,
        item: item,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('兑换成功！'),
              backgroundColor: Colors.green,
            ),
          );
          // 重新加载数据
          await _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('兑换失败，请检查积分是否充足'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('积分兑换'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 积分卡片
                    _buildPointsCard(),
                    const SizedBox(height: 16),

                    // 统计信息
                    _buildStatsCard(),
                    const SizedBox(height: 16),

                    // 可兑换商品
                    _buildRewardItemsSection(),
                    const SizedBox(height: 16),

                    // 兑换记录
                    _buildRewardRecordsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red[700]!, Colors.red[500]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.stars,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的积分',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '$_totalScore',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: '刷新',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.blue[600],
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_stats['totalItems'] ?? 0}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[600],
                      ),
                    ),
                    Text(
                      '兑换总数',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_stats['totalSpent'] ?? 0}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[600],
                      ),
                    ),
                    Text(
                      '消费积分',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItemsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.card_giftcard,
                color: Colors.red[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '可兑换商品',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_rewardItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无可兑换商品',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.55,
              ),
              itemCount: _rewardItems.length,
              itemBuilder: (context, index) => _buildRewardItemCard(_rewardItems[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildRewardItemCard(RewardItem item) {
    final canAfford = _totalScore >= item.points;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: canAfford ? () => _redeemItem(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 商品图片
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  item.cover,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 商品信息
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 商品名称 - 使用Flexible确保不会溢出
                    Flexible(
                      flex: 2,
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          color: Colors.orange[600],
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${item.points}积分',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: canAfford ? Colors.orange[600] : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: canAfford ? Colors.red[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        canAfford ? '立即兑换' : '积分不足',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: canAfford ? Colors.red[600] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardRecordsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.green[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '兑换记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _loadData,
                child: const Text('刷新', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_rewardRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '暂无兑换记录',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _rewardRecords
                  .map((record) => _buildRewardRecordItem(record))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRewardRecordItem(RewardRecord record) {
    Color statusColor;
    String statusText;

    switch (record.status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = '已完成';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = '已取消';
        break;
      default:
        statusColor = Colors.orange;
        statusText = '处理中';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              record.itemCover,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported,
                  size: 24,
                  color: Colors.grey[400],
                );
              },
            ),
          ),
        ),
        title: Text(
          record.itemName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${record.points}积分 · ${DateFormat('yyyy-MM-dd HH:mm').format(record.redeemedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}