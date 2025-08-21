import 'package:flutter/material.dart';

class CulturePage extends StatelessWidget {
  const CulturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 内容区域
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 红色文化板块
                _buildSectionCard(
                  title: '红色文化',
                  icon: Icons.flag,
                  color: Colors.red[600]!,
                  items: ['革命历史故事', '英雄人物事迹', '红色精神传承', '革命遗址介绍'],
                ),

                const SizedBox(height: 16),

                // 文旅板块
                _buildSectionCard(
                  title: '文旅资讯',
                  icon: Icons.travel_explore,
                  color: Colors.orange[600]!,
                  items: ['红色旅游路线', '文化景点推荐', '历史遗迹探索', '特色文化体验'],
                ),

                const SizedBox(height: 16),

                // 时政板块
                _buildSectionCard(
                  title: '时政要闻',
                  icon: Icons.newspaper,
                  color: Colors.blue[600]!,
                  items: ['重要政策解读', '时事热点分析', '社会发展动态', '国际形势观察'],
                ),

                const SizedBox(height: 16),

                // 学习进度
                _buildProgressCard(),

                const SizedBox(height: 100), // 底部留白
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right, color: color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  '学习进度',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              value: 0.65,
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            const Text(
              '已完成 65% 的学习内容',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
