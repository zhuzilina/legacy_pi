# 悬浮按钮组件 (FloatingActionButtons)

这是一个可复用的悬浮按钮组件，用于在页面中显示多个垂直排列的悬浮按钮。

## 功能特性

- 🎯 **可配置的按钮**: 支持自定义按钮文本、图标、颜色和回调函数
- 🎨 **美观的UI**: 圆形按钮设计，支持阴影效果
- 📱 **响应式布局**: 自动适应不同屏幕尺寸
- 🔧 **易于使用**: 提供便捷的构建器方法
- 🎭 **Overlay管理**: 自动管理Overlay的显示和隐藏
- 🧹 **内存安全**: 自动清理资源，避免内存泄漏

## 核心组件

### 1. FloatingButtonConfig
按钮配置类，定义单个按钮的属性：

```dart
FloatingButtonConfig(
  text: '按钮文本',
  onTap: () => print('按钮被点击'),
  backgroundColor: Colors.red,
  textColor: Colors.white,
  icon: Icons.star,
)
```

### 2. FloatingActionButtonsManager
悬浮按钮管理器，负责管理Overlay和按钮的生命周期：

```dart
final manager = FloatingActionButtonsManager(
  context: context,
  buttonConfigs: buttonConfigs,
  bottomOffset: 60,
  rightOffset: 20,
);

manager.show();  // 显示按钮
manager.hide();  // 隐藏按钮
manager.update(); // 更新按钮
manager.dispose(); // 销毁管理器
```

### 3. FloatingActionButtons
StatefulWidget组件，自动管理悬浮按钮的生命周期：

```dart
FloatingActionButtons(
  buttonConfigs: buttonConfigs,
  autoShow: true,
  onStateChanged: () => print('状态改变'),
)
```

## 便捷构建器

### FloatingActionButtonsBuilder

#### 1. buildArticleButtons
为文章页面创建标准的三个按钮（学习全文、总结要点、进入对话）：

```dart
final buttonConfigs = FloatingActionButtonsBuilder.buildArticleButtons(
  context: context,
  onStudyFullText: () => print('学习全文'),
  onSummarizeKeyPoints: () => print('总结要点'),
  onEnterConversation: () => print('进入对话'),
);
```

#### 2. buildCustomButtons
创建自定义按钮：

```dart
final buttonConfigs = FloatingActionButtonsBuilder.buildCustomButtons(
  texts: ['按钮1', '按钮2', '按钮3'],
  onTaps: [onTap1, onTap2, onTap3],
  backgroundColors: [Colors.blue, Colors.green, Colors.orange],
  textColors: [Colors.white, Colors.white, Colors.white],
  icons: [Icons.star, Icons.favorite, Icons.share],
);
```

## 使用示例

### 基本使用

```dart
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  FloatingActionButtonsManager? _manager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFloatingButtons();
    });
  }

  @override
  void dispose() {
    _manager?.dispose();
    super.dispose();
  }

  void _initializeFloatingButtons() {
    final buttonConfigs = FloatingActionButtonsBuilder.buildArticleButtons(
      context: context,
      onStudyFullText: _onStudyFullText,
      onSummarizeKeyPoints: _onSummarizeKeyPoints,
      onEnterConversation: _onEnterConversation,
    );

    _manager = FloatingActionButtonsManager(
      context: context,
      buttonConfigs: buttonConfigs,
    );

    _manager!.show();
  }

  void _onStudyFullText() {
    // 处理学习全文逻辑
  }

  void _onSummarizeKeyPoints() {
    // 处理总结要点逻辑
  }

  void _onEnterConversation() {
    // 处理进入对话逻辑
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的页面')),
      body: Center(child: Text('页面内容')),
    );
  }
}
```

### 使用FloatingActionButtons组件

```dart
class MyPage extends StatefulWidget {
  @override
  _MyPageState createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的页面')),
      body: Stack(
        children: [
          Center(child: Text('页面内容')),
          FloatingActionButtons(
            buttonConfigs: FloatingActionButtonsBuilder.buildArticleButtons(
              context: context,
              onStudyFullText: () => print('学习全文'),
              onSummarizeKeyPoints: () => print('总结要点'),
              onEnterConversation: () => print('进入对话'),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 配置选项

### FloatingActionButtonsManager 参数

- `context`: BuildContext，必需
- `buttonConfigs`: 按钮配置列表，必需
- `bottomOffset`: 距离底部的偏移量，默认60
- `rightOffset`: 距离右侧的偏移量，默认20
- `defaultBackgroundColor`: 默认背景色，默认红色
- `defaultTextColor`: 默认文字色，默认白色

### FloatingActionButtons 参数

- `buttonConfigs`: 按钮配置列表，必需
- `bottomOffset`: 距离底部的偏移量，默认60
- `rightOffset`: 距离右侧的偏移量，默认20
- `defaultBackgroundColor`: 默认背景色，默认红色
- `defaultTextColor`: 默认文字色，默认白色
- `autoShow`: 是否自动显示，默认true
- `onStateChanged`: 状态改变回调

## 注意事项

1. **内存管理**: 使用FloatingActionButtonsManager时，务必在dispose中调用dispose()方法
2. **Context使用**: 确保在正确的BuildContext中创建管理器
3. **按钮数量**: 建议按钮数量不超过5个，以确保良好的用户体验
4. **响应式设计**: 组件会自动适应屏幕尺寸，但建议测试不同设备上的显示效果

## 迁移指南

从旧的悬浮按钮实现迁移到新组件：

1. 导入新的组件：
```dart
import 'package:legacy_pi/widgets/floating_action_buttons.dart';
```

2. 替换旧的悬浮按钮状态管理：
```dart
// 旧代码
OverlayEntry? _floatingButtonOverlayEntry;

// 新代码
FloatingActionButtonsManager? _floatingButtonsManager;
```

3. 使用便捷构建器创建按钮配置：
```dart
final buttonConfigs = FloatingActionButtonsBuilder.buildArticleButtons(
  context: context,
  onStudyFullText: _onStudyFullText,
  onSummarizeKeyPoints: _onSummarizeKeyPoints,
  onEnterConversation: _onEnterConversation,
);
```

4. 更新生命周期管理：
```dart
@override
void dispose() {
  _floatingButtonsManager?.dispose();
  super.dispose();
}
```

这样就完成了从旧实现到新组件的迁移。
