import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:legacy_pi/pages/pk.dart';
import 'dart:convert';
import 'daily_question_page.dart';
import 'knowledge_detail_page.dart';
import 'recent_learning_page.dart';
import '../config/api_config.dart';

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // API状态管理
  Map<String, List<dynamic>> _knowledgeData = {
    'new_thought': [],
    'theory': [],
  };
  Map<String, bool> _loadingStates = {
    'new_thought': false,
    'theory': false,
  };
  Map<String, String> _errorStates = {
    'new_thought': '',
    'theory': '',
  };
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadKnowledgeData('new_thought');
    _loadKnowledgeData('theory');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // API方法

  Future<void> _loadKnowledgeData(String category) async {
    setState(() {
      _loadingStates[category] = true;
      _errorStates[category] = '';
    });

    try {
      final baseUrl = await ApiConfig.knowledgeQuizBaseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/knowledge/?category=$category'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _knowledgeData[category] = data['data']['knowledge_list'] ?? [];
            _loadingStates[category] = false;
          });
        } else {
          setState(() {
            _errorStates[category] = '获取知识数据失败';
            _loadingStates[category] = false;
          });
        }
      } else {
        setState(() {
          _errorStates[category] = '网络请求失败';
          _loadingStates[category] = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorStates[category] = '请求异常: $e';
        _loadingStates[category] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFunctionBlocks(),
                    const SizedBox(height: 20),
                    _buildTabBar(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildListContent('new_thought'),
            _buildListContent('theory'),
          ],
        ),
      ),
    );
  }

  // 功能区块
  Widget _buildFunctionBlocks() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.3,
      child: Column(
        children: [
          // 第一行：知识挑战和每日一答
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildFunctionCard(
                    title: '答题pk',
                    icon: Icons.emoji_events,
                    color: Colors.amber[600]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PKPage())
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFunctionCard(
                    title: '每日一答',
                    icon: Icons.quiz,
                    color: Colors.blue[600]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyQuestionPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 第二行：最近学习（全宽）
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildFunctionCard(
                    title: '最近学习',
                    icon: Icons.history,
                    color: Colors.green[600]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RecentLearningPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TabBar
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '新思想'),
          Tab(text: '知识理论'),
        ],
      ),
    );
  }

  // 列表内容
  Widget _buildListContent(String category) {
    if (_loadingStates[category]!) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorStates[category]!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorStates[category]!,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadKnowledgeData(category),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final knowledgeList = _knowledgeData[category]!;
    if (knowledgeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无知识内容',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: knowledgeList.length,
      itemBuilder: (context, index) {
        final knowledge = knowledgeList[index];
        return _buildKnowledgeCard(knowledge, category);
      },
    );
  }

  Widget _buildKnowledgeCard(Map<String, dynamic> knowledge, String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KnowledgeDetailPage(knowledge: knowledge),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      knowledge['title'] ?? '无标题',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      knowledge['source'] ?? '未知来源',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }



}
