// import 'package:flutter/material.dart';
// import 'package:legacy_pi/widgets/floating_action_buttons.dart';

// /// 悬浮按钮组件使用示例
// class FloatingActionButtonsExample extends StatefulWidget {
//   const FloatingActionButtonsExample({super.key});

//   @override
//   State<FloatingActionButtonsExample> createState() => _FloatingActionButtonsExampleState();
// }

// class _FloatingActionButtonsExampleState extends State<FloatingActionButtonsExample> {
//   FloatingActionButtonsManager? _manager;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _initializeFloatingButtons();
//     });
//   }

//   @override
//   void dispose() {
//     _manager?.dispose();
//     super.dispose();
//   }

//   void _initializeFloatingButtons() {
//     if (_manager != null) return;

//     // 使用便捷构建器创建文章相关的悬浮按钮
//     final buttonConfigs = FloatingActionButtonsBuilder.buildArticleButtons(
//       context: context,
//       onStudyFullText: _onStudyFullText,
//       onSummarizeKeyPoints: _onSummarizeKeyPoints,
//       onEnterConversation: _onEnterConversation,
//     );

//     _manager = FloatingActionButtonsManager(
//       context: context,
//       buttonConfigs: buttonConfigs,
//       bottomOffset: 60,
//       rightOffset: 20,
//     );

//     _manager!.show();
//   }


//   // 回调方法
//   void _onStudyFullText() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('学习全文功能')),
//     );
//   }

//   void _onSummarizeKeyPoints() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('总结要点功能')),
//     );
//   }

//   void _onEnterConversation() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('进入对话功能')),
//     );
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('悬浮按钮示例'),
//         actions: [
//           IconButton(
//             onPressed: () {
//               _manager?.hide();
//             },
//             icon: const Icon(Icons.visibility_off),
//             tooltip: '隐藏悬浮按钮',
//           ),
//           IconButton(
//             onPressed: () {
//               _manager?.show();
//             },
//             icon: const Icon(Icons.visibility),
//             tooltip: '显示悬浮按钮',
//           ),
//         ],
//       ),
//       body: const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               '悬浮按钮组件示例',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 20),
//             Text(
//               '右侧的悬浮按钮是使用新的组件创建的',
//               style: TextStyle(fontSize: 16),
//             ),
//             SizedBox(height: 20),
//             Text(
//               '可以通过AppBar上的按钮来隐藏/显示悬浮按钮',
//               style: TextStyle(fontSize: 14, color: Colors.grey),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
