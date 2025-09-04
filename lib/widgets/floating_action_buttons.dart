import 'package:flutter/material.dart';
import 'package:legacy_pi/l10n/app_localizations.dart';

/// 悬浮按钮配置项
class FloatingButtonConfig {
  final String text;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const FloatingButtonConfig({
    required this.text,
    required this.onTap,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });
}

/// 悬浮按钮管理器
class FloatingActionButtonsManager {
  OverlayEntry? _overlayEntry;
  final BuildContext _context;
  final List<FloatingButtonConfig> _buttonConfigs;
  final double _bottomOffset;
  final double _rightOffset;
  final Color _defaultBackgroundColor;
  final Color _defaultTextColor;

  FloatingActionButtonsManager({
    required BuildContext context,
    required List<FloatingButtonConfig> buttonConfigs,
    double bottomOffset = 60,
    double rightOffset = 20,
    Color defaultBackgroundColor = const Color(0xFFD32F2F), // Colors.red[700]
    Color defaultTextColor = Colors.white,
  }) : _context = context,
       _buttonConfigs = buttonConfigs,
       _bottomOffset = bottomOffset,
       _rightOffset = rightOffset,
       _defaultBackgroundColor = defaultBackgroundColor,
       _defaultTextColor = defaultTextColor;

  /// 显示悬浮按钮
  void show() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: _bottomOffset,
        right: _rightOffset,
        child: _buildFloatingButtons(),
      ),
    );

    Overlay.of(_context).insert(_overlayEntry!);
  }

  /// 隐藏悬浮按钮
  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 更新悬浮按钮
  void update() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  /// 销毁悬浮按钮
  void dispose() {
    hide();
  }

  /// 构建悬浮按钮组
  Widget _buildFloatingButtons() {
    return SizedBox(
      width: 120,
      height: MediaQuery.of(_context).size.height / 3,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _buttonConfigs.asMap().entries.map((entry) {
          final index = entry.key;
          final config = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < _buttonConfigs.length - 1 ? 8 : 0),
            child: _buildFloatingButton(config),
          );
        }).toList(),
      ),
    );
  }

  /// 构建单个悬浮按钮
  Widget _buildFloatingButton(FloatingButtonConfig config) {
    final backgroundColor = config.backgroundColor ?? _defaultBackgroundColor;
    final textColor = config.textColor ?? _defaultTextColor;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: config.onTap,
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Center(
              child: config.icon != null
                  ? Icon(
                      config.icon,
                      size: 20,
                      color: textColor,
                    )
                  : Text(
                      config.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 悬浮按钮组件
class FloatingActionButtons extends StatefulWidget {
  final List<FloatingButtonConfig> buttonConfigs;
  final double bottomOffset;
  final double rightOffset;
  final Color defaultBackgroundColor;
  final Color defaultTextColor;
  final bool autoShow;
  final VoidCallback? onStateChanged;

  const FloatingActionButtons({
    super.key,
    required this.buttonConfigs,
    this.bottomOffset = 60,
    this.rightOffset = 20,
    this.defaultBackgroundColor = const Color(0xFFD32F2F),
    this.defaultTextColor = Colors.white,
    this.autoShow = true,
    this.onStateChanged,
  });

  @override
  State<FloatingActionButtons> createState() => _FloatingActionButtonsState();
}

class _FloatingActionButtonsState extends State<FloatingActionButtons> {
  FloatingActionButtonsManager? _manager;

  @override
  void initState() {
    super.initState();
    if (widget.autoShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showButtons();
      });
    }
  }

  @override
  void didUpdateWidget(FloatingActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.buttonConfigs != oldWidget.buttonConfigs) {
      _updateButtons();
    }
  }

  @override
  void dispose() {
    _manager?.dispose();
    super.dispose();
  }

  void _showButtons() {
    _manager = FloatingActionButtonsManager(
      context: context,
      buttonConfigs: widget.buttonConfigs,
      bottomOffset: widget.bottomOffset,
      rightOffset: widget.rightOffset,
      defaultBackgroundColor: widget.defaultBackgroundColor,
      defaultTextColor: widget.defaultTextColor,
    );
    _manager!.show();
    widget.onStateChanged?.call();
  }

  void _hideButtons() {
    _manager?.hide();
    widget.onStateChanged?.call();
  }

  void _updateButtons() {
    _manager?.dispose();
    _showButtons();
  }

  /// 显示悬浮按钮
  void show() {
    if (_manager == null) {
      _showButtons();
    } else {
      _manager!.show();
    }
  }

  /// 隐藏悬浮按钮
  void hide() {
    _hideButtons();
  }

  /// 更新悬浮按钮
  void update() {
    _manager?.update();
  }

  @override
  Widget build(BuildContext context) {
    // 这个组件不渲染任何UI，只管理悬浮按钮的生命周期
    return const SizedBox.shrink();
  }
}

/// 便捷的悬浮按钮构建器
class FloatingActionButtonsBuilder {
  static List<FloatingButtonConfig> buildArticleButtons({
    required BuildContext context,
    required VoidCallback onStudyFullText,
    required VoidCallback onSummarizeKeyPoints,
    required VoidCallback onEnterConversation,
  }) {
    final l10n = AppLocalizations.of(context)!;
    
    return [
      FloatingButtonConfig(
        text: l10n.studyFullText,
        onTap: onStudyFullText,
      ),
      FloatingButtonConfig(
        text: l10n.summarizeKeyPoints,
        onTap: onSummarizeKeyPoints,
      ),
      FloatingButtonConfig(
        text: l10n.enterConversation,
        onTap: onEnterConversation,
      ),
    ];
  }

  static List<FloatingButtonConfig> buildCustomButtons({
    required List<String> texts,
    required List<VoidCallback> onTaps,
    List<Color>? backgroundColors,
    List<Color>? textColors,
    List<IconData>? icons,
  }) {
    assert(texts.length == onTaps.length, '文本和回调数量必须相等');
    assert(backgroundColors == null || backgroundColors.length == texts.length, '背景色数量必须与文本数量相等');
    assert(textColors == null || textColors.length == texts.length, '文字色数量必须与文本数量相等');
    assert(icons == null || icons.length == texts.length, '图标数量必须与文本数量相等');

    return texts.asMap().entries.map((entry) {
      final index = entry.key;
      final text = entry.value;
      
      return FloatingButtonConfig(
        text: text,
        onTap: onTaps[index],
        backgroundColor: backgroundColors?[index],
        textColor: textColors?[index],
        icon: icons?[index],
      );
    }).toList();
  }
}
