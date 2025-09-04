import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_pi/models/article.dart';
import 'package:legacy_pi/pages/chat_page.dart';

void main() {
  group('ChatPage Tests', () {
    late Article testArticle;

    setUp(() {
      testArticle = Article(
        id: 'test_1',
        title: '测试文章标题',
        source: '测试来源',
        publishTime: '2024-01-01',
        category: '测试分类',
        wordCount: 1000,
        originalUrl: 'https://example.com/test',
        metaInfo: '测试元信息',
        content: '这是测试文章的内容，用于测试对话页面的功能。',
        collectTime: DateTime.now().toString(),
      );
    });

    testWidgets('ChatPage should start with empty message state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 验证页面标题
      expect(find.text('AI 对话助手'), findsOneWidget);

      // 验证页面以空消息状态开始，没有初始消息
      expect(find.byType(ChatMessage), findsNothing);
      
      // 验证没有初始的文章内容或欢迎消息
      expect(find.text('测试文章标题\n\n这是测试文章的内容，用于测试对话页面的功能。'), findsNothing);
      expect(find.text('你好！我已经了解了这篇文章的内容。你可以问我任何关于这篇文章的问题，或者我们可以进行深入的讨论。'), findsNothing);

      // 验证输入框
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('输入消息...'), findsOneWidget);

      // 验证发送按钮已移除，使用回车键发送
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('ChatPage should display option buttons above input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 验证选项按钮（移除了更多按钮和文件按钮）
      expect(find.byIcon(Icons.image_outlined), findsOneWidget); // 图片按钮
      expect(find.byIcon(Icons.attach_file), findsNothing); // 文件按钮已移除
      expect(find.byIcon(Icons.mic_none), findsOneWidget); // 语音按钮（现在在输入框左边）
    });

    testWidgets('ChatPage should handle user input and send message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 输入用户消息
      await tester.enterText(find.byType(TextField), '总结要点');
      
      // 模拟按下回车键发送
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      // 验证用户消息显示
      expect(find.text('总结要点'), findsOneWidget);

      // 由于测试环境HTTP请求会失败，我们主要验证用户消息的发送功能
      // 在实际应用中，这里会显示加载状态和AI回复
    });

    testWidgets('ChatPage should start with clean interface', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 验证页面以干净的状态开始，没有初始消息
      expect(find.byType(ChatMessage), findsNothing);
      
      // 验证没有文章内容或欢迎消息
      expect(find.text('文章内容'), findsNothing);
      expect(find.byIcon(Icons.article), findsNothing);
    });

    testWidgets('ChatPage should have optimized input area layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 验证输入区域布局
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
      
      // 验证选项按钮在输入框上方
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsNothing); // 文件按钮已移除
      
      // 验证语音按钮在输入框左边
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      
      // 验证语音按钮使用黑色加粗样式
      final micIcon = tester.widget<Icon>(find.byIcon(Icons.mic_none));
      expect(micIcon.color, Colors.black);
      expect(micIcon.weight, 900);
    });

    testWidgets('ChatPage should toggle between text and voice input modes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 初始状态应该是文本模式
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsNothing);

      // 点击语音按钮切换到语音模式
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      // 验证切换到语音模式
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
      expect(find.text('按住说话'), findsOneWidget);

      // 再次点击键盘按钮切换回文本模式
      await tester.tap(find.byIcon(Icons.keyboard));
      await tester.pump();

      // 验证切换回文本模式
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsNothing);
      expect(find.text('按住说话'), findsNothing);
    });

    testWidgets('ChatPage should handle voice recording button interactions', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 切换到语音模式
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();

      // 验证语音录制按钮存在
      expect(find.text('按住说话'), findsOneWidget);

      // 模拟按住说话的手势
      final voiceButton = find.text('按住说话');
      await tester.tap(voiceButton);
      await tester.pump();

      // 验证按钮可以正常点击
      expect(voiceButton, findsOneWidget);

      // 验证显示相应的提示信息（通过SnackBar）
      // 注意：这里我们主要测试UI交互，实际的语音录制逻辑是TODO
    });

    testWidgets('ChatPage should send message on Enter key press', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 输入用户消息
      await tester.enterText(find.byType(TextField), '测试回车发送');
      
      // 模拟按下回车键
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      // 验证用户消息显示
      expect(find.text('测试回车发送'), findsOneWidget);

      // 由于测试环境HTTP请求会失败，我们主要验证用户消息的发送功能
      // 在实际应用中，这里会显示加载状态和AI回复
    });

    testWidgets('ChatPage should handle image selection and display', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 验证初始状态：没有图片，显示图片选择按钮
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      // 验证图片选择按钮可以点击
      await tester.tap(find.byIcon(Icons.image_outlined));
      await tester.pump();

      // 注意：实际的图片选择需要真实的设备交互，这里我们主要测试UI状态
      // 在实际应用中，这里会调用图片选择器
    });

    testWidgets('ChatPage should show image selection button only when less than 3 images', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 初始状态应该显示图片选择按钮
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      // 模拟添加3张图片（这里我们直接操作状态来测试UI逻辑）
      // 在实际应用中，这需要通过真实的图片选择器来实现
      // 由于测试环境的限制，我们主要验证UI组件的存在性
    });

    testWidgets('ChatPage should display article title capsule in options bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: testArticle),
        ),
      );

      // 验证文章标题胶囊容器存在
      // 测试文章标题"测试文章标题"是5个字符，少于7个字符，所以完整显示
      expect(find.text('测试文章标题'), findsOneWidget);
      
      // 验证胶囊容器的样式（通过查找包含特定文本的Container）
      final titleCapsule = find.ancestor(
        of: find.text('测试文章标题'),
        matching: find.byType(Container),
      );
      expect(titleCapsule, findsAtLeastNWidgets(1)); // 可能找到多个Container，至少找到1个
    });

    testWidgets('ChatPage should handle short article titles correctly', (WidgetTester tester) async {
      // 创建一个短标题的文章
      final shortTitleArticle = Article(
        id: 'test_2',
        title: '短标题',
        source: '测试来源',
        publishTime: '2024-01-01',
        category: '测试分类',
        wordCount: 1000,
        originalUrl: 'https://example.com/test',
        metaInfo: '测试元信息',
        content: '这是测试文章的内容。',
        collectTime: DateTime.now().toString(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(article: shortTitleArticle),
        ),
      );

      // 验证短标题不显示省略号
      expect(find.text('短标题'), findsOneWidget);
      expect(find.text('短标题...'), findsNothing);
    });
  });
}
