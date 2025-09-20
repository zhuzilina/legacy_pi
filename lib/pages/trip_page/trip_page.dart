import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
// 引入自定义组件
import 'widget/strategy_card.dart';
import 'widget/section_title.dart';
import 'widget/scenic_attraction_card.dart';
import '../act_detail_page.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {

  // 轮播图控制器
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // 攻略数据
  List<Map<String, dynamic>> strategies = [];

  // 活动数据
  List<Map<String, dynamic>> _actData = [];
  bool _isLoadingAct = true;

  
  final List<Map<String, dynamic>> teams = [
    {
      'avatar': 'https://picsum.photos/50?random=1',
      'name': '赵一曼故居参观',
      'date': '8月20日',
      'members': 3,
    },
    {
      'avatar': 'https://picsum.photos/50?random=2',
      'name': '江姐故居参观',
      'date': '8月22日',
      'members': 5,
    },
  ];

  
  
  @override
  void initState() {
    super.initState();
    _loadStrategiesData();
    _loadActData();
    _startAutoScroll();
  }

  // 加载攻略数据
  Future<void> _loadStrategiesData() async {
    try {
      final String response = await rootBundle.loadString('assets/config/strategies.json');
      final List<dynamic> data = await json.decode(response);
      setState(() {
        strategies = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('加载攻略数据失败: $e');
      // 如果加载失败，使用默认数据
      setState(() {
        strategies = [
          {
            'id': 1,
            'title': '鲁迅纪念馆参观攻略',
            'description': '这是一篇详细的鲁迅纪念馆参观攻略，包含了开放时间、门票信息、交通指南、主要展品介绍、参观路线建议、注意事项等内容，帮助您更好地规划参观行程。',
            'image': 'http://www.luxunmuseum.com.cn/data/attached/4b5ce2fe28308fd9/image/20250415/17447007818454.jpg',
            'url': 'https://www.luxunmuseum.com.cn'
          },
          {
            'id': 2,
            'title': '遵义会议会址旅游攻略',
            'description': '遵义会议会址旅游攻略，详细介绍红色旅游景点，包括历史背景、参观路线、周边景点、住宿推荐、美食介绍、交通方式，让您的红色之旅更加充实有意义。',
            'image': 'https://www.zunyihy.cn/n342/20220411/880/material/2f7caa1a-4c05-43c3-8482-461108fd9a40.jpg',
            'url': 'https://www.zunyihy.cn'
          },
          {
            'id': 3,
            'title': '井冈山革命根据地深度游',
            'description': '井冈山革命根据地深度旅游攻略，包含主要景点介绍、最佳游览季节、登山路线建议、红色文化体验、住宿餐饮推荐、交通指南，带您重走红军路。',
            'image': 'https://picsum.photos/400/200?random=1',
            'url': 'https://jgs.gov.cn'
          },
          {
            'id': 4,
            'title': '延安革命圣地游览指南',
            'description': '延安革命圣地完整游览指南，涵盖枣园、杨家岭、王家坪等主要景点，历史文化介绍，游览路线规划，当地特色美食，住宿建议和交通信息。',
            'image': 'https://picsum.photos/400/200?random=2',
            'url': 'https://www.yanannormal.com'
          },
          {
            'id': 5,
            'title': '西柏坡红色教育之旅',
            'description': '西柏坡红色教育旅游攻略，包括景点介绍、历史意义、参观路线、教育意义、周边景点推荐、交通住宿信息，是进行爱国主义教育的理想目的地。',
            'image': 'https://picsum.photos/400/200?random=3',
            'url': 'https://www.xibaipo.com'
          },
          {
            'id': 6,
            'title': '中共一大会址参观指南',
            'description': '中共一大会址详细参观指南，包含历史背景介绍、参观须知、展品特色、预约方式、周边红色景点、交通路线、参观时长建议等实用信息。',
            'image': 'http://pic.people.com.cn/mediafile/pic/BIG/20230519/5/12397810148944316541.jpg',
            'url': 'https://www.zgshyc.com'
          }
        ];
      });
    }
  }

  // 加载活动数据
  Future<void> _loadActData() async {
    try {
      final String response = await rootBundle.loadString('assets/config/act.json');
      final List<dynamic> data = await json.decode(response);
      setState(() {
        _actData = data.cast<Map<String, dynamic>>();
        _isLoadingAct = false;
      });
    } catch (e) {
      debugPrint('加载活动数据失败: $e');
      setState(() {
        _isLoadingAct = false;
      });
    }
  }

  // 开始自动滚动
  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        final itemCount = _actData.isEmpty ? 1 : _actData.length;
        int nextPage = (_currentPage + 1) % itemCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 停止自动滚动
  void _stopAutoScroll() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onPanDown: (_) {
                        _stopAutoScroll();
                      },
                      onPanEnd: (_) {
                        _startAutoScroll();
                      },
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _actData.isEmpty ? 1 : _actData.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          if (_isLoadingAct) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (_actData.isEmpty) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '暂无活动数据',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final act = _actData[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActDetailPage(
                                    title: '活动详情',
                                    contentPath: act['content'],
                                    coverImage: act['cover'],
                                  ),
                                ),
                              );
                            },
                            child: Image.asset(
                              act['cover'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _actData.isEmpty ? 1 : _actData.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.red[700]
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: SectionTitle(title: '热门景点', action: '查看更多'),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverToBoxAdapter(
              child: const ScenicAttractionCard(),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: SectionTitle(title: '热门攻略', action: '更多推荐'),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => StrategyCard(strategy: strategies[index]),
                childCount: strategies.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
