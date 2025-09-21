# 红色文化学习App

一个充满正能量的红色文化学习应用，致力于传播红色文化、弘扬革命精神，为用户提供丰富的学习资源和互动体验。

## 🌟 应用特色

### 🎯 核心功能
- **学文化页面**：App的主页面，采用PageView垂直滚动布局
- **新旅途页面**：全屏地图展示，探索红色足迹
- **学知识页面**：马克思主义原理和红色理论学习
- **个人中心**：用户信息、积分成就、学习记录管理
- **图书阅读器**：优化的书籍阅读体验，支持智能分页
- **活动详情**：丰富的红色文化活动展示
- **全文阅读**：支持富文本内容显示和TTS语音播报

### 📱 页面布局

#### 主界面结构
- **学文化页面**（首页）
  - 红色文化内容展示
  - 文旅信息浏览
  - 时政要闻阅读
  - 垂直滚动PageView布局

- **新旅途页面**（左侧）
  - 全屏地图界面
  - 红色景点探索
  - 历史足迹追踪

- **学知识页面**（右侧）
  - 马克思主义原理学习
  - 红色理论教育
  - 与学文化页面相同的布局结构

#### 个人中心（抽屉式菜单）
- **用户信息展示**
- **积分和成就系统**
- **学习记录列表**
- **应用设置入口**

### 🎨 交互设计
- 左上角浮动"更多"按钮
- 左侧抽屉式菜单弹出
- 流畅的页面切换动画
- 直观的用户界面设计
- 智能滚动控制（自动隐藏/显示播放器）

## 🛠 技术架构

- **框架**：Flutter (Dart)
- **布局**：PageView + Drawer + Stack
- **地图**：集成地图服务
- **数据存储**：SQLite + SharedPreferences + 缓存系统
- **网络**：HTTP请求 + 数据缓存
- **多媒体**：音频播放 + 图片缓存 + WebView
- **AI功能**：智能对话服务

### 核心依赖
- `sqflite`: SQLite数据库
- `shared_preferences`: 本地存储
- `http`: 网络请求
- `audioplayers`: 音频播放
- `cached_network_image`: 图片缓存
- `flutter_inappwebview`: WebView
- `defer_pointer`: 手势处理优化

## 开发环境

确保您的开发环境满足以下要求：

- Flutter SDK (^3.8.1)
- Dart SDK
- Android Studio / VS Code
- Android SDK / Xcode (iOS开发)

## 快速开始

1. 克隆项目
```bash
git clone [项目地址]
cd legacy_pi
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行应用
```bash
flutter run
```

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口
├── pages/                       # 页面文件
│   ├── act_detail_page.dart     # 活动详情页面
│   ├── book_reader_page.dart    # 图书阅读器
│   ├── culture_page.dart        # 学文化页面
│   ├── journey_page.dart        # 新旅途页面
│   ├── knowledge_page.dart      # 学知识页面
│   ├── profile_page.dart        # 个人中心页面
│   └── chat_page.dart           # AI对话页面
├── widgets/                     # 自定义组件
│   ├── full_content_dialog.dart # 全文内容对话框
│   ├── rich_content_widget.dart # 富文本组件
│   ├── ai_explanation_widget.dart # AI解释组件
│   └── floating_action_buttons.dart # 悬浮按钮组件
├── services/                    # 服务层
│   ├── ai_service.dart          # AI服务
│   ├── tts_service.dart         # 语音合成服务
│   ├── unified_cache_service.dart # 统一缓存服务
│   ├── party_history_quiz_service.dart # 党史问答服务
│   └── chat_record_service.dart  # 聊天记录服务
├── models/                      # 数据模型
│   ├── article.dart             # 文章模型
│   └── content_item.dart       # 内容项模型
├── database/                    # 数据库
│   └── database_helper.dart     # 数据库助手
├── l10n/                        # 国际化
└── config/                      # 配置文件
```

## 🚀 功能模块

### 学文化模块
- 红色文化内容展示
- 文旅信息浏览
- 时政要闻阅读
- 垂直滚动布局
- 全文内容对话框

### 新旅途模块
- 全屏地图展示
- 红色景点标记
- 历史足迹追踪
- 地理位置服务

### 学知识模块
- 马克思主义原理
- 红色理论学习
- 党史知识问答
- 学习进度跟踪

### 图书阅读模块
- 智能分页算法
- 动态字体调整
- 阅读进度追踪
- AI选文问答功能
- 支持长文本选择和智能对话

### 全文阅读模块
- 富文本内容显示
- TTS语音播报
- 多种音色选择
- 自动播放设置
- 滚动隐藏播放器
- 音频缓存机制

### AI交互模块
- 智能对话系统
- 文章内容解释
- 历史知识问答
- 上下文理解

### 个人中心模块
- 用户信息管理
- 积分成就系统
- 学习记录统计
- 应用设置配置

## 🎯 最新更新

### 优化功能
- **积分系统优化**：修复积分更新bug，提升数据一致性
- **图书阅读器**：新增智能分页、AI问答功能
- **全文对话框**：优化TTS语音播报，支持音色选择和自动播放
- **缓存机制**：改进文本和音频缓存，提升性能
- **UI体验**：优化滚动交互，自动隐藏播放器控件

### 新增特性
- **活动详情页面**：支持红色文化活动展示
- **语音设置持久化**：记住用户选择的音色和播放偏好
- **错误处理优化**：增强网络异常和播放错误的处理
- **性能优化**：减少内存占用，提升加载速度

## 🤝 贡献指南

欢迎为项目贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) - 查看 LICENSE 文件了解详情。

## 📞 联系我们

如有问题或建议，请通过以下方式联系：

- 项目Issues：[GitHub Issues](项目地址/issues)
- 邮箱：[联系邮箱]

---

**让红色文化在新时代焕发新光彩！** 🌟

**传承红色基因，弘扬革命精神，共筑中国梦！** 🚩
