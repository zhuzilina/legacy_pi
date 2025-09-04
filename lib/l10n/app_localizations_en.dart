// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Legacy Pi';

  @override
  String get news => 'News';

  @override
  String get spirit => 'Spirit';

  @override
  String get people => 'People';

  @override
  String get partyHistory => 'Party History';

  @override
  String get loading => 'Loading';

  @override
  String loadingContent(String category) {
    return 'Loading $category content...';
  }

  @override
  String get loadFailed => 'Load Failed';

  @override
  String loadError(String error) {
    return 'Error loading content: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String noContent(String category) {
    return 'No $category Content';
  }

  @override
  String noContentDescription(String category) {
    return 'Currently no $category content available';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get viewMore => 'View More';

  @override
  String source(String source) {
    return 'Source: $source';
  }

  @override
  String get studyFullText => 'Study\nFull Text';

  @override
  String get summarizeKeyPoints => 'Summarize\nKey Points';

  @override
  String get enterConversation => 'Enter\nConversation';

  @override
  String get aiInterpretation => 'AI Interpretation';

  @override
  String get aiInterpreting => 'AI Interpreting';

  @override
  String get aiGeneratedContent => 'AI Generated Content, Please Use with Caution';

  @override
  String get aiInterpretationFailed => 'AI Interpretation Failed';

  @override
  String requestError(String error) {
    return 'Request Error: $error';
  }

  @override
  String get articleContent => 'Article Content';

  @override
  String get autoPlay => 'Auto Play';

  @override
  String get autoPlayDescription => 'Automatically play audio after AI interpretation';

  @override
  String get voiceSelection => 'Voice Selection';

  @override
  String get voiceSelectionDescription => 'Select TTS voice tone';

  @override
  String get audioSettings => 'Audio Settings';

  @override
  String get xiaoxiao => 'Xiaoxiao (Female)';

  @override
  String get yunxi => 'Yunxi (Male)';

  @override
  String get yunyang => 'Yunyang (Male)';

  @override
  String get xiaoyi => 'Xiaoyi (Female)';

  @override
  String get yunjian => 'Yunjian (Male)';

  @override
  String get xiaohan => 'Xiaohan (Female)';

  @override
  String get xiaomo => 'Xiaomo (Female)';

  @override
  String get xiaoxuan => 'Xiaoxuan (Female)';

  @override
  String get xiaoyan => 'Xiaoyan (Female)';

  @override
  String get yunfeng => 'Yunfeng (Male)';
}
