import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
// 引入自定义组件
import 'widget/team_card.dart';
import 'widget/strategy_card.dart';
import 'widget/section_title.dart';

class TripPage extends StatefulWidget {
  const TripPage({super.key});

  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {

  // 轮播图控制器
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 攻略数据
  List<Map<String, dynamic>> strategies = [];

  // 轮播图数据
  final List<String> carouselImages = [
    'https://img.zcool.cn/community/01640b5d32a7e9a8012187f4471cf4.jpg',
    'https://img.zcool.cn/community/01d88c5d32a7eaa8012187f416cf60.jpg',
    'https://img.zcool.cn/community/0199855d32a7eaa8012187f474c644.jpg',
    'https://img.zcool.cn/community/015b4c5d32a7e9a8012187f440d646.jpg',
  ];

  // 模拟数据
  final List<Map<String, dynamic>> attractions = [
    {
      'image':
          'http://pic.people.com.cn/mediafile/pic/BIG/20230519/5/12397810148944316541.jpg',
      'title': '中共一大会址',
      'desc': '红色的发源地',
    },
    {
      'image':
          'https://www.zunyihy.cn/n342/20220411/880/material/2f7caa1a-4c05-43c3-8482-461108fd9a40.jpg',
      'title': '遵义会议会址',
      'desc': '生死攸关的伟大转折',
    },
  ];

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

  // 热门景点数据
  final List<Map<String, dynamic>> popularAttractions = [
    {
      'image': 'http://pic.people.com.cn/mediafile/pic/BIG/20230519/5/12397810148944316541.jpg',
      'name': '中共一大会址',
      'location': '上海市黄浦区兴业路76号',
      'rating': 4.8,
      'visitors': 12500,
    },
    {
      'image': 'https://www.zunyihy.cn/n342/20220411/880/material/2f7caa1a-4c05-43c3-8482-461108fd9a40.jpg',
      'name': '遵义会议会址',
      'location': '贵州省遵义市红花岗区子尹路96号',
      'rating': 4.9,
      'visitors': 8900,
    },
    {
      'image': 'http://www.luxunmuseum.com.cn/data/attached/4b5ce2fe28308fd9/image/20250415/17447007818454.jpg',
      'name': '鲁迅纪念馆',
      'location': '上海市虹口区甜爱路200号',
      'rating': 4.7,
      'visitors': 6700,
    },
    {
      'image': 'https://picsum.photos/280/140?random=3',
      'name': '井冈山革命博物馆',
      'location': '江西省井冈山市茨坪镇',
      'rating': 4.8,
      'visitors': 10200,
    },
  ];

  
  @override
  void initState() {
    super.initState();
    _loadStrategiesData();
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
            'image': 'http://www.luxunmuseum.com.cn/data/attached/4b5ce2fe28308fd9/image/20250415/17447007818454.jpg'
          },
          {
            'id': 2,
            'title': '遵义会议会址旅游攻略',
            'description': '遵义会议会址旅游攻略，详细介绍红色旅游景点，包括历史背景、参观路线、周边景点、住宿推荐、美食介绍、交通方式，让您的红色之旅更加充实有意义。',
            'image': 'https://www.zunyihy.cn/n342/20220411/880/material/2f7caa1a-4c05-43c3-8482-461108fd9a40.jpg'
          },
          {
            'id': 3,
            'title': '井冈山革命根据地深度游',
            'description': '井冈山革命根据地深度旅游攻略，包含主要景点介绍、最佳游览季节、登山路线建议、红色文化体验、住宿餐饮推荐、交通指南，带您重走红军路。',
            'image': 'https://picsum.photos/400/200?random=1'
          },
          {
            'id': 4,
            'title': '延安革命圣地游览指南',
            'description': '延安革命圣地完整游览指南，涵盖枣园、杨家岭、王家坪等主要景点，历史文化介绍，游览路线规划，当地特色美食，住宿建议和交通信息。',
            'image': 'https://picsum.photos/400/200?random=2'
          },
          {
            'id': 5,
            'title': '西柏坡红色教育之旅',
            'description': '西柏坡红色教育旅游攻略，包括景点介绍、历史意义、参观路线、教育意义、周边景点推荐、交通住宿信息，是进行爱国主义教育的理想目的地。',
            'image': 'https://picsum.photos/400/200?random=3'
          },
          {
            'id': 6,
            'title': '中共一大会址参观指南',
            'description': '中共一大会址详细参观指南，包含历史背景介绍、参观须知、展品特色、预约方式、周边红色景点、交通路线、参观时长建议等实用信息。',
            'image': 'http://pic.people.com.cn/mediafile/pic/BIG/20230519/5/12397810148944316541.jpg'
          }
        ];
      });
    }
  }

  @override
  void dispose() {
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
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: carouselImages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          carouselImages[index],
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
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      carouselImages.length,
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
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: popularAttractions.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) => AttractionCard(attraction: popularAttractions[index]),
                ),
              ),
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

class AiInputWidget extends StatefulWidget {
  const AiInputWidget({super.key});
  @override
  State<StatefulWidget> createState() {
    return _AiInputWidgetState();
  }
}

class _AiInputWidgetState extends State<AiInputWidget> {
  final TextEditingController inputControl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '小旅助手',
            style: Theme.of(context).textTheme.displaySmall!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 60,
            width: 300,
            child: TextField(
              controller: inputControl,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(40)),
                ),
                hint: Text(
                  '向小旅游助手提问',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: EdgeInsets.only(left: 30), child: Text('建议:')),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 7,
                children: [
                  SizedBox(
                    width: 160,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(10, 2, 2, 2),
                        child: Text(
                          '规划一下去遵义旅游的行程',
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(10, 2, 2, 2),
                        child: Text(
                          '最近热门',
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 165,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(10, 2, 2, 2),
                        child: Text(
                          '去红色场馆参观的注意事项',
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(flex: 1, child: SizedBox(height: 1)),
            ],
          ),
        ],
      ),
    );
  }
}
