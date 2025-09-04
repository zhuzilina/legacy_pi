import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Legacy Pi'**
  String get appTitle;

  /// News category tab
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get news;

  /// Spirit category tab
  ///
  /// In en, this message translates to:
  /// **'Spirit'**
  String get spirit;

  /// People category tab
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// Party history category tab
  ///
  /// In en, this message translates to:
  /// **'Party History'**
  String get partyHistory;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Loading content for specific category
  ///
  /// In en, this message translates to:
  /// **'Loading {category} content...'**
  String loadingContent(String category);

  /// Load failed title
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get loadFailed;

  /// Error message when loading fails
  ///
  /// In en, this message translates to:
  /// **'Error loading content: {error}'**
  String loadError(String error);

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No content message for specific category
  ///
  /// In en, this message translates to:
  /// **'No {category} Content'**
  String noContent(String category);

  /// Description when no content is available
  ///
  /// In en, this message translates to:
  /// **'Currently no {category} content available'**
  String noContentDescription(String category);

  /// Refresh button text
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// View more button text
  ///
  /// In en, this message translates to:
  /// **'View More'**
  String get viewMore;

  /// Source information
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String source(String source);

  /// Study full text button
  ///
  /// In en, this message translates to:
  /// **'Study\nFull Text'**
  String get studyFullText;

  /// Summarize key points button
  ///
  /// In en, this message translates to:
  /// **'Summarize\nKey Points'**
  String get summarizeKeyPoints;

  /// Enter conversation button
  ///
  /// In en, this message translates to:
  /// **'Enter\nConversation'**
  String get enterConversation;

  /// AI interpretation dialog title
  ///
  /// In en, this message translates to:
  /// **'AI Interpretation'**
  String get aiInterpretation;

  /// AI is interpreting text
  ///
  /// In en, this message translates to:
  /// **'AI Interpreting'**
  String get aiInterpreting;

  /// Warning about AI generated content
  ///
  /// In en, this message translates to:
  /// **'AI Generated Content, Please Use with Caution'**
  String get aiGeneratedContent;

  /// AI interpretation failed message
  ///
  /// In en, this message translates to:
  /// **'AI Interpretation Failed'**
  String get aiInterpretationFailed;

  /// Request error message
  ///
  /// In en, this message translates to:
  /// **'Request Error: {error}'**
  String requestError(String error);

  /// Article content title
  ///
  /// In en, this message translates to:
  /// **'Article Content'**
  String get articleContent;

  /// Auto play setting
  ///
  /// In en, this message translates to:
  /// **'Auto Play'**
  String get autoPlay;

  /// Auto play setting description
  ///
  /// In en, this message translates to:
  /// **'Automatically play audio after AI interpretation'**
  String get autoPlayDescription;

  /// Voice selection setting
  ///
  /// In en, this message translates to:
  /// **'Voice Selection'**
  String get voiceSelection;

  /// Voice selection setting description
  ///
  /// In en, this message translates to:
  /// **'Select TTS voice tone'**
  String get voiceSelectionDescription;

  /// Audio settings title
  ///
  /// In en, this message translates to:
  /// **'Audio Settings'**
  String get audioSettings;

  /// Xiaoxiao voice option
  ///
  /// In en, this message translates to:
  /// **'Xiaoxiao (Female)'**
  String get xiaoxiao;

  /// Yunxi voice option
  ///
  /// In en, this message translates to:
  /// **'Yunxi (Male)'**
  String get yunxi;

  /// Yunyang voice option
  ///
  /// In en, this message translates to:
  /// **'Yunyang (Male)'**
  String get yunyang;

  /// Xiaoyi voice option
  ///
  /// In en, this message translates to:
  /// **'Xiaoyi (Female)'**
  String get xiaoyi;

  /// Yunjian voice option
  ///
  /// In en, this message translates to:
  /// **'Yunjian (Male)'**
  String get yunjian;

  /// Xiaohan voice option
  ///
  /// In en, this message translates to:
  /// **'Xiaohan (Female)'**
  String get xiaohan;

  /// Xiaomo voice option
  ///
  /// In en, this message translates to:
  /// **'Xiaomo (Female)'**
  String get xiaomo;

  /// Xiaoxuan voice option
  ///
  /// In en, this message translates to:
  /// **'Xiaoxuan (Female)'**
  String get xiaoxuan;

  /// Xiaoyan voice option
  ///
  /// In en, this message translates to:
  /// **'Xiaoyan (Female)'**
  String get xiaoyan;

  /// Yunfeng voice option
  ///
  /// In en, this message translates to:
  /// **'Yunfeng (Male)'**
  String get yunfeng;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
