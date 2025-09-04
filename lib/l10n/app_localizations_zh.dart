// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '传承派';

  @override
  String get news => '新闻';

  @override
  String get spirit => '精神';

  @override
  String get people => '人物';

  @override
  String get partyHistory => '党史';

  @override
  String get loading => '加载中';

  @override
  String loadingContent(String category) {
    return '正在加载$category内容...';
  }

  @override
  String get loadFailed => '加载失败';

  @override
  String loadError(String error) {
    return '加载内容时发生错误: $error';
  }

  @override
  String get retry => '重试';

  @override
  String noContent(String category) {
    return '暂无$category内容';
  }

  @override
  String noContentDescription(String category) {
    return '当前没有可显示的$category内容';
  }

  @override
  String get refresh => '刷新';

  @override
  String get viewMore => '查看更多';

  @override
  String source(String source) {
    return '来源: $source';
  }

  @override
  String get studyFullText => '学习\n全文';

  @override
  String get summarizeKeyPoints => '总结\n要点';

  @override
  String get enterConversation => '进入\n对话';

  @override
  String get aiInterpretation => 'AI解读';

  @override
  String get aiInterpreting => 'AI解读中';

  @override
  String get aiGeneratedContent => 'AI生成内容，请谨慎对待';

  @override
  String get aiInterpretationFailed => 'AI解读失败';

  @override
  String requestError(String error) {
    return '请求异常: $error';
  }

  @override
  String get articleContent => '文章内容';

  @override
  String get autoPlay => '自动播放';

  @override
  String get autoPlayDescription => 'AI解读完成后自动播放音频';

  @override
  String get voiceSelection => '音色选择';

  @override
  String get voiceSelectionDescription => '选择TTS语音的音色';

  @override
  String get audioSettings => '音频设置';

  @override
  String get xiaoxiao => '晓晓 (女声)';

  @override
  String get yunxi => '云希 (男声)';

  @override
  String get yunyang => '云扬 (男声)';

  @override
  String get xiaoyi => '晓伊 (女声)';

  @override
  String get yunjian => '云健 (男声)';

  @override
  String get xiaohan => '晓涵 (女声)';

  @override
  String get xiaomo => '晓墨 (女声)';

  @override
  String get xiaoxuan => '晓萱 (女声)';

  @override
  String get xiaoyan => '晓颜 (女声)';

  @override
  String get yunfeng => '云枫 (男声)';
}
