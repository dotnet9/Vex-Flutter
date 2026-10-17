import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
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
/// import 'generated/app_localizations.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @mapLayoutRight.
  ///
  /// In zh, this message translates to:
  /// **'单侧树形'**
  String get mapLayoutRight;

  /// No description provided for @mapLayoutBalanced.
  ///
  /// In zh, this message translates to:
  /// **'双侧平衡'**
  String get mapLayoutBalanced;

  /// No description provided for @mapLayoutRadial.
  ///
  /// In zh, this message translates to:
  /// **'中心放射'**
  String get mapLayoutRadial;

  /// No description provided for @mapLayoutDown.
  ///
  /// In zh, this message translates to:
  /// **'向下树形'**
  String get mapLayoutDown;

  /// No description provided for @mapLayoutOutline.
  ///
  /// In zh, this message translates to:
  /// **'目录树'**
  String get mapLayoutOutline;

  /// No description provided for @mapLayoutFishbone.
  ///
  /// In zh, this message translates to:
  /// **'鱼骨图'**
  String get mapLayoutFishbone;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @insertTable.
  ///
  /// In zh, this message translates to:
  /// **'插入表格'**
  String get insertTable;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @insert.
  ///
  /// In zh, this message translates to:
  /// **'插入'**
  String get insert;

  /// No description provided for @tableSizeHint.
  ///
  /// In zh, this message translates to:
  /// **'设置表格大小，第一行为表头。'**
  String get tableSizeHint;

  /// No description provided for @rows.
  ///
  /// In zh, this message translates to:
  /// **'行数'**
  String get rows;

  /// No description provided for @columns.
  ///
  /// In zh, this message translates to:
  /// **'列数'**
  String get columns;

  /// No description provided for @tableRowsHint.
  ///
  /// In zh, this message translates to:
  /// **'1–100 行，包含表头'**
  String get tableRowsHint;

  /// No description provided for @tableColumnsHint.
  ///
  /// In zh, this message translates to:
  /// **'1–20 列'**
  String get tableColumnsHint;

  /// No description provided for @generating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成…'**
  String get generating;

  /// No description provided for @sentToPrinter.
  ///
  /// In zh, this message translates to:
  /// **'已发送到系统打印窗口。'**
  String get sentToPrinter;

  /// No description provided for @printCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消打印。'**
  String get printCancelled;

  /// No description provided for @exportCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消导出。'**
  String get exportCancelled;

  /// No description provided for @exportShare.
  ///
  /// In zh, this message translates to:
  /// **'导出与分享'**
  String get exportShare;

  /// No description provided for @exportDescription.
  ///
  /// In zh, this message translates to:
  /// **'将当前内容保存为独立文件。HTML 保留所选配色与排版，导图图片包含完整结构。'**
  String get exportDescription;

  /// No description provided for @htmlPage.
  ///
  /// In zh, this message translates to:
  /// **'HTML 页面'**
  String get htmlPage;

  /// No description provided for @pdfDocument.
  ///
  /// In zh, this message translates to:
  /// **'PDF 文档'**
  String get pdfDocument;

  /// No description provided for @wordDocument.
  ///
  /// In zh, this message translates to:
  /// **'Word 文档'**
  String get wordDocument;

  /// No description provided for @mindMapPng.
  ///
  /// In zh, this message translates to:
  /// **'导图 PNG'**
  String get mindMapPng;

  /// No description provided for @systemPrint.
  ///
  /// In zh, this message translates to:
  /// **'系统打印'**
  String get systemPrint;

  /// No description provided for @copyHtml.
  ///
  /// In zh, this message translates to:
  /// **'复制 HTML 源码'**
  String get copyHtml;

  /// No description provided for @htmlCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 HTML 源码。'**
  String get htmlCopied;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观与排版'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'明暗模式'**
  String get themeMode;

  /// No description provided for @light.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get dark;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @interfaceColors.
  ///
  /// In zh, this message translates to:
  /// **'界面配色'**
  String get interfaceColors;

  /// No description provided for @bodyTypography.
  ///
  /// In zh, this message translates to:
  /// **'正文排版'**
  String get bodyTypography;

  /// No description provided for @compactSpacing.
  ///
  /// In zh, this message translates to:
  /// **'紧凑间距'**
  String get compactSpacing;

  /// No description provided for @appearancePreservesSource.
  ///
  /// In zh, this message translates to:
  /// **'排版与配色不会改变 Markdown 原文。'**
  String get appearancePreservesSource;

  /// No description provided for @summarySettings.
  ///
  /// In zh, this message translates to:
  /// **'导图摘要设置'**
  String get summarySettings;

  /// No description provided for @paragraphs.
  ///
  /// In zh, this message translates to:
  /// **'段落正文'**
  String get paragraphs;

  /// No description provided for @lists.
  ///
  /// In zh, this message translates to:
  /// **'列表内容'**
  String get lists;

  /// No description provided for @quotesCodeTables.
  ///
  /// In zh, this message translates to:
  /// **'引用、代码和表格'**
  String get quotesCodeTables;

  /// No description provided for @summaryDescription.
  ///
  /// In zh, this message translates to:
  /// **'摘要只影响导图显示。点击节点可查看并编辑整节正文。'**
  String get summaryDescription;

  /// No description provided for @restoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get restoreDefaults;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @editor.
  ///
  /// In zh, this message translates to:
  /// **'编辑器'**
  String get editor;

  /// No description provided for @sourceLineNumbers.
  ///
  /// In zh, this message translates to:
  /// **'源码行号'**
  String get sourceLineNumbers;

  /// No description provided for @localFiles.
  ///
  /// In zh, this message translates to:
  /// **'本地文件'**
  String get localFiles;

  /// No description provided for @localFilesDescription.
  ///
  /// In zh, this message translates to:
  /// **'编辑时自动保留恢复草稿。保存会写入原文件；检测到其他程序的修改时，会先提示你处理。移动设备通过系统文件选择器保存。'**
  String get localFilesDescription;

  /// No description provided for @openSourceLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源组件许可'**
  String get openSourceLicenses;

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'笺纬 Texweft'**
  String get appTitle;

  /// No description provided for @checking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查…'**
  String get checking;

  /// No description provided for @noRelease.
  ///
  /// In zh, this message translates to:
  /// **'尚无已发布的正式版本。'**
  String get noRelease;

  /// No description provided for @githubUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法连接 GitHub，可稍后重试。'**
  String get githubUnavailable;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于笺纬'**
  String get about;

  /// No description provided for @slogan.
  ///
  /// In zh, this message translates to:
  /// **'落笔成文，思路成形。'**
  String get slogan;

  /// No description provided for @nativeApplication.
  ///
  /// In zh, this message translates to:
  /// **'Flutter 原生应用'**
  String get nativeApplication;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'把 Markdown 写作、阅读与思维导图放在同一个工作区。内容保存在本地，使用开放的文件格式。'**
  String get aboutDescription;

  /// No description provided for @author.
  ///
  /// In zh, this message translates to:
  /// **'沙漠尽头的狼 / CodeWF'**
  String get author;

  /// No description provided for @authorWebsite.
  ///
  /// In zh, this message translates to:
  /// **'作者网站'**
  String get authorWebsite;

  /// No description provided for @githubSource.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 源码'**
  String get githubSource;

  /// No description provided for @releasesDownloads.
  ///
  /// In zh, this message translates to:
  /// **'发布与下载'**
  String get releasesDownloads;

  /// No description provided for @checkUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdates;

  /// No description provided for @acknowledgements.
  ///
  /// In zh, this message translates to:
  /// **'感谢 Flutter、Dart、flutter_markdown_plus、markdown、文件与窗口管理、导出等开源组件，以及 Cascadia Code、Noto Sans SC 字体的贡献者。各组件和字体遵循各自的许可证，完整声明见“开源组件许可”。'**
  String get acknowledgements;

  /// No description provided for @markdownSource.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 源码'**
  String get markdownSource;

  /// No description provided for @bodyPreview.
  ///
  /// In zh, this message translates to:
  /// **'正文预览'**
  String get bodyPreview;

  /// No description provided for @mindMap.
  ///
  /// In zh, this message translates to:
  /// **'思维导图'**
  String get mindMap;

  /// No description provided for @instantEditing.
  ///
  /// In zh, this message translates to:
  /// **'即时编辑'**
  String get instantEditing;

  /// No description provided for @addSection.
  ///
  /// In zh, this message translates to:
  /// **'新增章节'**
  String get addSection;

  /// No description provided for @childSection.
  ///
  /// In zh, this message translates to:
  /// **'子章节'**
  String get childSection;

  /// No description provided for @arrange.
  ///
  /// In zh, this message translates to:
  /// **'编排'**
  String get arrange;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'折叠'**
  String get collapse;

  /// No description provided for @summary.
  ///
  /// In zh, this message translates to:
  /// **'摘要设置'**
  String get summary;

  /// No description provided for @emptyDocument.
  ///
  /// In zh, this message translates to:
  /// **'这篇文档还是空白。'**
  String get emptyDocument;

  /// No description provided for @sectionArrangement.
  ///
  /// In zh, this message translates to:
  /// **'章节编排'**
  String get sectionArrangement;

  /// No description provided for @sectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'章节标题'**
  String get sectionTitle;

  /// No description provided for @moveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get moveDown;

  /// No description provided for @promote.
  ///
  /// In zh, this message translates to:
  /// **'升级'**
  String get promote;

  /// No description provided for @demote.
  ///
  /// In zh, this message translates to:
  /// **'降级'**
  String get demote;

  /// No description provided for @sibling.
  ///
  /// In zh, this message translates to:
  /// **'同级'**
  String get sibling;

  /// No description provided for @child.
  ///
  /// In zh, this message translates to:
  /// **'子级'**
  String get child;

  /// No description provided for @sectionBody.
  ///
  /// In zh, this message translates to:
  /// **'本节正文'**
  String get sectionBody;

  /// No description provided for @sectionBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'只编辑本节正文，子章节会完整保留。'**
  String get sectionBodyHint;

  /// No description provided for @deleteSection.
  ///
  /// In zh, this message translates to:
  /// **'删除章节'**
  String get deleteSection;

  /// No description provided for @keepBody.
  ///
  /// In zh, this message translates to:
  /// **'保留正文'**
  String get keepBody;

  /// No description provided for @deleteWholeSection.
  ///
  /// In zh, this message translates to:
  /// **'删除整节'**
  String get deleteWholeSection;

  /// No description provided for @deleteSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'可以连同正文和子章节一起删除，或只移除标题。此操作可撤销。'**
  String get deleteSectionHint;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @workspaceLayout.
  ///
  /// In zh, this message translates to:
  /// **'工作区布局'**
  String get workspaceLayout;

  /// No description provided for @markdownTypography.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 排版'**
  String get markdownTypography;

  /// No description provided for @closePicker.
  ///
  /// In zh, this message translates to:
  /// **'关闭选择面板'**
  String get closePicker;

  /// No description provided for @layoutHint.
  ///
  /// In zh, this message translates to:
  /// **'选择后立即切换，所有视图共享同一份内容'**
  String get layoutHint;

  /// No description provided for @typographyHint.
  ///
  /// In zh, this message translates to:
  /// **'六种阅读结构 · 与界面配色分别设置'**
  String get typographyHint;

  /// No description provided for @sampleHeading.
  ///
  /// In zh, this message translates to:
  /// **'落笔成文'**
  String get sampleHeading;

  /// No description provided for @unsavedContent.
  ///
  /// In zh, this message translates to:
  /// **'还有未保存的内容'**
  String get unsavedContent;

  /// No description provided for @keepDraftClose.
  ///
  /// In zh, this message translates to:
  /// **'保留草稿并关闭'**
  String get keepDraftClose;

  /// No description provided for @saveAll.
  ///
  /// In zh, this message translates to:
  /// **'全部保存'**
  String get saveAll;

  /// No description provided for @imageMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'![图片说明](图片路径)'**
  String get imageMarkdown;

  /// No description provided for @documentChanged.
  ///
  /// In zh, this message translates to:
  /// **'文档已变化，请重新选择表格插入位置。'**
  String get documentChanged;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @discard.
  ///
  /// In zh, this message translates to:
  /// **'丢弃'**
  String get discard;

  /// No description provided for @externalChange.
  ///
  /// In zh, this message translates to:
  /// **'原文件已被其他程序修改'**
  String get externalChange;

  /// No description provided for @reload.
  ///
  /// In zh, this message translates to:
  /// **'重新载入'**
  String get reload;

  /// No description provided for @loadExternalChanges.
  ///
  /// In zh, this message translates to:
  /// **'载入外部修改'**
  String get loadExternalChanges;

  /// No description provided for @load.
  ///
  /// In zh, this message translates to:
  /// **'载入'**
  String get load;

  /// No description provided for @loadExternalHint.
  ///
  /// In zh, this message translates to:
  /// **'当前改动可以通过撤销恢复。确认载入外部文件的内容？'**
  String get loadExternalHint;

  /// No description provided for @saveCurrentAs.
  ///
  /// In zh, this message translates to:
  /// **'另存当前内容'**
  String get saveCurrentAs;

  /// No description provided for @exitPresentation.
  ///
  /// In zh, this message translates to:
  /// **'退出演示'**
  String get exitPresentation;

  /// No description provided for @dropMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'放开以打开 Markdown 文件'**
  String get dropMarkdown;

  /// No description provided for @menuFile.
  ///
  /// In zh, this message translates to:
  /// **'文件(F)'**
  String get menuFile;

  /// No description provided for @newDocument.
  ///
  /// In zh, this message translates to:
  /// **'新建文档'**
  String get newDocument;

  /// No description provided for @open.
  ///
  /// In zh, this message translates to:
  /// **'打开…'**
  String get open;

  /// No description provided for @openFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹…'**
  String get openFolder;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In zh, this message translates to:
  /// **'另存为…'**
  String get saveAs;

  /// No description provided for @exportShareMenu.
  ///
  /// In zh, this message translates to:
  /// **'导出与分享…'**
  String get exportShareMenu;

  /// No description provided for @exit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exit;

  /// No description provided for @menuEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑(E)'**
  String get menuEdit;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get redo;

  /// No description provided for @cut.
  ///
  /// In zh, this message translates to:
  /// **'剪切'**
  String get cut;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @find.
  ///
  /// In zh, this message translates to:
  /// **'查找'**
  String get find;

  /// No description provided for @replace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get replace;

  /// No description provided for @menuInsert.
  ///
  /// In zh, this message translates to:
  /// **'插入(I)'**
  String get menuInsert;

  /// No description provided for @heading.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get heading;

  /// No description provided for @quote.
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get quote;

  /// No description provided for @link.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get link;

  /// No description provided for @image.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get image;

  /// No description provided for @codeBlock.
  ///
  /// In zh, this message translates to:
  /// **'代码块'**
  String get codeBlock;

  /// No description provided for @table.
  ///
  /// In zh, this message translates to:
  /// **'表格'**
  String get table;

  /// No description provided for @horizontalRule.
  ///
  /// In zh, this message translates to:
  /// **'分隔线'**
  String get horizontalRule;

  /// No description provided for @menuView.
  ///
  /// In zh, this message translates to:
  /// **'视图(V)'**
  String get menuView;

  /// No description provided for @workspaceLayoutMenu.
  ///
  /// In zh, this message translates to:
  /// **'工作区布局…'**
  String get workspaceLayoutMenu;

  /// No description provided for @toggleSidebar.
  ///
  /// In zh, this message translates to:
  /// **'显示/隐藏侧栏'**
  String get toggleSidebar;

  /// No description provided for @focusMode.
  ///
  /// In zh, this message translates to:
  /// **'专注模式'**
  String get focusMode;

  /// No description provided for @presentationMode.
  ///
  /// In zh, this message translates to:
  /// **'演示模式'**
  String get presentationMode;

  /// No description provided for @appearanceMenu.
  ///
  /// In zh, this message translates to:
  /// **'外观与排版…'**
  String get appearanceMenu;

  /// No description provided for @menuTools.
  ///
  /// In zh, this message translates to:
  /// **'工具(T)'**
  String get menuTools;

  /// No description provided for @menuHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助(H)'**
  String get menuHelp;

  /// No description provided for @quickStart.
  ///
  /// In zh, this message translates to:
  /// **'快速上手'**
  String get quickStart;

  /// No description provided for @aboutUpdates.
  ///
  /// In zh, this message translates to:
  /// **'关于笺纬 / 检查更新'**
  String get aboutUpdates;

  /// No description provided for @toggleTheme.
  ///
  /// In zh, this message translates to:
  /// **'切换明暗模式'**
  String get toggleTheme;

  /// No description provided for @minimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get minimize;

  /// No description provided for @maximizeRestore.
  ///
  /// In zh, this message translates to:
  /// **'最大化 / 还原'**
  String get maximizeRestore;

  /// No description provided for @filesOutline.
  ///
  /// In zh, this message translates to:
  /// **'文件与大纲'**
  String get filesOutline;

  /// No description provided for @quickStartBadge.
  ///
  /// In zh, this message translates to:
  /// **'• 快速上手'**
  String get quickStartBadge;

  /// No description provided for @layoutDropdown.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get layoutDropdown;

  /// No description provided for @findTooltip.
  ///
  /// In zh, this message translates to:
  /// **'查找 · Ctrl+F'**
  String get findTooltip;

  /// No description provided for @saveTooltip.
  ///
  /// In zh, this message translates to:
  /// **'保存 · Ctrl+S'**
  String get saveTooltip;

  /// No description provided for @newAction.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get newAction;

  /// No description provided for @layout.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get layout;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @read.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get read;

  /// No description provided for @map.
  ///
  /// In zh, this message translates to:
  /// **'导图'**
  String get map;

  /// No description provided for @instantRendering.
  ///
  /// In zh, this message translates to:
  /// **'即时渲染'**
  String get instantRendering;

  /// No description provided for @source.
  ///
  /// In zh, this message translates to:
  /// **'源码'**
  String get source;

  /// No description provided for @bold.
  ///
  /// In zh, this message translates to:
  /// **'加粗'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get italic;

  /// No description provided for @unorderedList.
  ///
  /// In zh, this message translates to:
  /// **'无序列表'**
  String get unorderedList;

  /// No description provided for @orderedList.
  ///
  /// In zh, this message translates to:
  /// **'有序列表'**
  String get orderedList;

  /// No description provided for @taskList.
  ///
  /// In zh, this message translates to:
  /// **'任务列表'**
  String get taskList;

  /// No description provided for @inlineCode.
  ///
  /// In zh, this message translates to:
  /// **'行内代码'**
  String get inlineCode;

  /// No description provided for @moreFormatting.
  ///
  /// In zh, this message translates to:
  /// **'更多格式'**
  String get moreFormatting;

  /// No description provided for @findText.
  ///
  /// In zh, this message translates to:
  /// **'查找文本'**
  String get findText;

  /// No description provided for @matchCase.
  ///
  /// In zh, this message translates to:
  /// **'区分大小写'**
  String get matchCase;

  /// No description provided for @regularExpression.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get regularExpression;

  /// No description provided for @wholeWord.
  ///
  /// In zh, this message translates to:
  /// **'整词'**
  String get wholeWord;

  /// No description provided for @nextMatch.
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get nextMatch;

  /// No description provided for @closeFind.
  ///
  /// In zh, this message translates to:
  /// **'关闭查找'**
  String get closeFind;

  /// No description provided for @replaceWith.
  ///
  /// In zh, this message translates to:
  /// **'替换为'**
  String get replaceWith;

  /// No description provided for @replaceAll.
  ///
  /// In zh, this message translates to:
  /// **'全部替换'**
  String get replaceAll;

  /// No description provided for @unsaved.
  ///
  /// In zh, this message translates to:
  /// **'未保存'**
  String get unsaved;

  /// No description provided for @unmodified.
  ///
  /// In zh, this message translates to:
  /// **'未修改'**
  String get unmodified;

  /// No description provided for @writing.
  ///
  /// In zh, this message translates to:
  /// **'写作'**
  String get writing;

  /// No description provided for @guideWriteTitle.
  ///
  /// In zh, this message translates to:
  /// **'写下第一句话'**
  String get guideWriteTitle;

  /// No description provided for @guideWriteBody.
  ///
  /// In zh, this message translates to:
  /// **'点击正文，直接修改内容。即时编辑和源码使用同一份 Markdown。'**
  String get guideWriteBody;

  /// No description provided for @guideViewsTitle.
  ///
  /// In zh, this message translates to:
  /// **'两个视角，同一份内容'**
  String get guideViewsTitle;

  /// No description provided for @guideViewsBody.
  ///
  /// In zh, this message translates to:
  /// **'左侧编辑源码，右侧立即查看正文。试着添加一个标题。'**
  String get guideViewsBody;

  /// No description provided for @guideMapTitle.
  ///
  /// In zh, this message translates to:
  /// **'看见文章的脉络'**
  String get guideMapTitle;

  /// No description provided for @guideMapBody.
  ///
  /// In zh, this message translates to:
  /// **'导图显示章节与正文摘要。拖动画布、折叠分支，试试双击章节。'**
  String get guideMapBody;

  /// No description provided for @guideArrangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'直接整理章节'**
  String get guideArrangeTitle;

  /// No description provided for @guideArrangeBody.
  ///
  /// In zh, this message translates to:
  /// **'使用新增章节和编排工具，修改标题、正文、顺序或层级。所有改动都可以撤销。'**
  String get guideArrangeBody;

  /// No description provided for @guideTypographyTitle.
  ///
  /// In zh, this message translates to:
  /// **'找到适合文字的排版'**
  String get guideTypographyTitle;

  /// No description provided for @guideTypographyBody.
  ///
  /// In zh, this message translates to:
  /// **'打开排版，比较六种正文样式。配色与排版不会改变原文。'**
  String get guideTypographyBody;

  /// No description provided for @guideFinishTitle.
  ///
  /// In zh, this message translates to:
  /// **'开始自己的写作'**
  String get guideFinishTitle;

  /// No description provided for @guideFinishBody.
  ///
  /// In zh, this message translates to:
  /// **'完成后恢复进入引导前的内容和撤销历史，再打开或新建自己的文档。'**
  String get guideFinishBody;

  /// No description provided for @endGuide.
  ///
  /// In zh, this message translates to:
  /// **'结束'**
  String get endGuide;

  /// No description provided for @previous.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get previous;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @files.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get files;

  /// No description provided for @outline.
  ///
  /// In zh, this message translates to:
  /// **'大纲'**
  String get outline;

  /// No description provided for @documentStructure.
  ///
  /// In zh, this message translates to:
  /// **'文档结构'**
  String get documentStructure;

  /// No description provided for @outlineHint.
  ///
  /// In zh, this message translates to:
  /// **'使用 # 标题来组织内容。'**
  String get outlineHint;

  /// No description provided for @searchDocuments.
  ///
  /// In zh, this message translates to:
  /// **'搜索文档…'**
  String get searchDocuments;

  /// No description provided for @notes.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get notes;

  /// No description provided for @openMarkdownFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开 Markdown 文件夹'**
  String get openMarkdownFolder;

  /// No description provided for @recentlyOpened.
  ///
  /// In zh, this message translates to:
  /// **'最近打开'**
  String get recentlyOpened;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageHint.
  ///
  /// In zh, this message translates to:
  /// **'切换界面语言，文档内容保持原样。'**
  String get languageHint;

  /// No description provided for @codeLanguage.
  ///
  /// In zh, this message translates to:
  /// **'代码语言'**
  String get codeLanguage;

  /// No description provided for @writingPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'从第一句话开始…'**
  String get writingPlaceholder;

  /// No description provided for @newParagraph.
  ///
  /// In zh, this message translates to:
  /// **'新增段落'**
  String get newParagraph;

  /// No description provided for @zoomOut.
  ///
  /// In zh, this message translates to:
  /// **'缩小'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In zh, this message translates to:
  /// **'放大'**
  String get zoomIn;

  /// No description provided for @fitCanvas.
  ///
  /// In zh, this message translates to:
  /// **'适应画布'**
  String get fitCanvas;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @untitled.
  ///
  /// In zh, this message translates to:
  /// **'无标题'**
  String get untitled;

  /// No description provided for @untitledFile.
  ///
  /// In zh, this message translates to:
  /// **'未命名.md'**
  String get untitledFile;

  /// No description provided for @emptyFolder.
  ///
  /// In zh, this message translates to:
  /// **'空文件夹'**
  String get emptyFolder;

  /// No description provided for @recoveredDraftFile.
  ///
  /// In zh, this message translates to:
  /// **'恢复的草稿.md'**
  String get recoveredDraftFile;

  /// No description provided for @invalidRegex.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式无效'**
  String get invalidRegex;

  /// No description provided for @finishGuideBeforeSaving.
  ///
  /// In zh, this message translates to:
  /// **'请先结束引导演练，再保存自己的文档。'**
  String get finishGuideBeforeSaving;

  /// No description provided for @fileConflict.
  ///
  /// In zh, this message translates to:
  /// **'文件已被其他程序修改，请重新载入或另存为，避免覆盖外部改动。'**
  String get fileConflict;

  /// No description provided for @layoutSourceRender.
  ///
  /// In zh, this message translates to:
  /// **'源码＋渲染'**
  String get layoutSourceRender;

  /// No description provided for @layoutSourceMap.
  ///
  /// In zh, this message translates to:
  /// **'源码＋导图'**
  String get layoutSourceMap;

  /// No description provided for @layoutInstantMap.
  ///
  /// In zh, this message translates to:
  /// **'即时编辑＋导图'**
  String get layoutInstantMap;

  /// No description provided for @layoutThree.
  ///
  /// In zh, this message translates to:
  /// **'源码＋渲染＋导图'**
  String get layoutThree;

  /// No description provided for @typeSimple.
  ///
  /// In zh, this message translates to:
  /// **'简约'**
  String get typeSimple;

  /// No description provided for @typeDocument.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get typeDocument;

  /// No description provided for @typeBook.
  ///
  /// In zh, this message translates to:
  /// **'书卷'**
  String get typeBook;

  /// No description provided for @typeTechnical.
  ///
  /// In zh, this message translates to:
  /// **'技术'**
  String get typeTechnical;

  /// No description provided for @typeColumn.
  ///
  /// In zh, this message translates to:
  /// **'专栏'**
  String get typeColumn;

  /// No description provided for @typeEditorial.
  ///
  /// In zh, this message translates to:
  /// **'刊物'**
  String get typeEditorial;

  /// No description provided for @typeSimpleNote.
  ///
  /// In zh, this message translates to:
  /// **'日常写作 · 清爽留白'**
  String get typeSimpleNote;

  /// No description provided for @typeDocumentNote.
  ///
  /// In zh, this message translates to:
  /// **'知识整理 · 清晰分节'**
  String get typeDocumentNote;

  /// No description provided for @typeBookNote.
  ///
  /// In zh, this message translates to:
  /// **'散文长读 · 衬线字形'**
  String get typeBookNote;

  /// No description provided for @typeTechnicalNote.
  ///
  /// In zh, this message translates to:
  /// **'开发笔记 · 信息模块'**
  String get typeTechnicalNote;

  /// No description provided for @typeColumnNote.
  ///
  /// In zh, this message translates to:
  /// **'观点文章 · 鲜明层次'**
  String get typeColumnNote;

  /// No description provided for @typeEditorialNote.
  ///
  /// In zh, this message translates to:
  /// **'发布阅读 · 窄栏节奏'**
  String get typeEditorialNote;

  /// No description provided for @paletteWeft.
  ///
  /// In zh, this message translates to:
  /// **'品牌墨青'**
  String get paletteWeft;

  /// No description provided for @paletteGraphite.
  ///
  /// In zh, this message translates to:
  /// **'石墨'**
  String get paletteGraphite;

  /// No description provided for @paletteOcean.
  ///
  /// In zh, this message translates to:
  /// **'海蓝'**
  String get paletteOcean;

  /// No description provided for @paletteSand.
  ///
  /// In zh, this message translates to:
  /// **'沙金'**
  String get paletteSand;

  /// No description provided for @paletteRose.
  ///
  /// In zh, this message translates to:
  /// **'蔷薇'**
  String get paletteRose;

  /// No description provided for @paletteIris.
  ///
  /// In zh, this message translates to:
  /// **'鸢尾'**
  String get paletteIris;

  /// No description provided for @paletteOlive.
  ///
  /// In zh, this message translates to:
  /// **'橄榄'**
  String get paletteOlive;

  /// No description provided for @paletteEmber.
  ///
  /// In zh, this message translates to:
  /// **'陶朱'**
  String get paletteEmber;

  /// No description provided for @integerRange.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1–{max} 之间的整数'**
  String integerRange(int max);

  /// No description provided for @exportedFile.
  ///
  /// In zh, this message translates to:
  /// **'已导出 {name}'**
  String exportedFile(String name);

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// No description provided for @summaryLength.
  ///
  /// In zh, this message translates to:
  /// **'摘要长度：{count} 字'**
  String summaryLength(int count);

  /// No description provided for @bodyFontSize.
  ///
  /// In zh, this message translates to:
  /// **'正文字号：{size} px'**
  String bodyFontSize(int size);

  /// No description provided for @updateHttpError.
  ///
  /// In zh, this message translates to:
  /// **'检查失败（HTTP {code}），可前往发布页查看。'**
  String updateHttpError(int code);

  /// No description provided for @latestVersion.
  ///
  /// In zh, this message translates to:
  /// **'GitHub 最新版本：{version}'**
  String latestVersion(String version);

  /// No description provided for @showPaneOnly.
  ///
  /// In zh, this message translates to:
  /// **'单独显示{title}'**
  String showPaneOnly(String title);

  /// No description provided for @deleteNamedSection.
  ///
  /// In zh, this message translates to:
  /// **'删除「{title}」'**
  String deleteNamedSection(String title);

  /// No description provided for @unsavedDocuments.
  ///
  /// In zh, this message translates to:
  /// **'{count} 篇文档尚未保存。可以保存到文件，或保留恢复草稿后关闭。'**
  String unsavedDocuments(int count);

  /// No description provided for @recoveryDraftCount.
  ///
  /// In zh, this message translates to:
  /// **'发现 {count} 篇恢复草稿'**
  String recoveryDraftCount(int count);

  /// No description provided for @typographyDropdown.
  ///
  /// In zh, this message translates to:
  /// **'排版 {name}'**
  String typographyDropdown(String name);

  /// No description provided for @matchCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 处匹配'**
  String matchCount(int count);

  /// No description provided for @cursorPosition.
  ///
  /// In zh, this message translates to:
  /// **'行 {line}，列 {column}'**
  String cursorPosition(int line, int column);

  /// No description provided for @characterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字符'**
  String characterCount(int count);

  /// No description provided for @preferencesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'偏好或恢复草稿读取失败：{error}'**
  String preferencesLoadFailed(String error);

  /// No description provided for @savedFile.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {name}'**
  String savedFile(String name);

  /// No description provided for @fileReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'原文件暂时无法读取：{error}'**
  String fileReadFailed(String error);

  /// No description provided for @recoverySaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复草稿保存失败：{error}'**
  String recoverySaveFailed(String error);

  /// No description provided for @preferencesSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'偏好保存失败：{error}'**
  String preferencesSaveFailed(String error);

  /// No description provided for @sectionLevel.
  ///
  /// In zh, this message translates to:
  /// **'H{level} · 章节'**
  String sectionLevel(int level);

  /// No description provided for @markdownDocument.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 文档'**
  String get markdownDocument;

  /// No description provided for @tableColumn.
  ///
  /// In zh, this message translates to:
  /// **'标题{number}'**
  String tableColumn(int number);

  /// No description provided for @saveNamedFile.
  ///
  /// In zh, this message translates to:
  /// **'保存 {name}'**
  String saveNamedFile(String name);

  /// No description provided for @newSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'新章节'**
  String get newSectionTitle;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailed(String error);

  /// No description provided for @sampleDesignName.
  ///
  /// In zh, this message translates to:
  /// **'主题设计笔记.md'**
  String get sampleDesignName;

  /// No description provided for @sampleWeeklyName.
  ///
  /// In zh, this message translates to:
  /// **'每周复盘.md'**
  String get sampleWeeklyName;

  /// No description provided for @sampleReadingName.
  ///
  /// In zh, this message translates to:
  /// **'读书摘录.md'**
  String get sampleReadingName;

  /// No description provided for @sampleStartName.
  ///
  /// In zh, this message translates to:
  /// **'快速开始.md'**
  String get sampleStartName;

  /// No description provided for @sampleExportName.
  ///
  /// In zh, this message translates to:
  /// **'导出指南.md'**
  String get sampleExportName;

  /// No description provided for @sampleDesign.
  ///
  /// In zh, this message translates to:
  /// **'# 主题设计笔记\n\n让写作、阅读与结构梳理共享同一份 Markdown，切换视角时保留正在关注的内容。\n\n## 设计原则\n\n### 保持沉浸感\n\n把注意力留给内容。写作时保留必要工具，阅读和梳理结构时让文档占据更多空间。\n\n### 降低视觉噪音\n\n用层级、留白和少量强调色表达关系，避免让边框、按钮和状态提示争夺注意力。\n\n## 主题色体系\n\n主题需要同时照顾浅色与深色。强调色用于选中、定位和主要操作，正文保持稳定对比度。\n\n- 浅色与深色独立选择\n- 八套配色共用语义令牌\n\n## 排版与字距\n\n正文以舒适阅读为先，标题层级清晰。导图中的段落默认截取三十个字，点击后可查看完整内容。\n\n## 导出一致性\n\n> 同一份内容，在编辑器、阅读视图与导出文件中，都应该保留清晰的结构。\n\n| 输出格式 | 使用场景 |\n| --- | --- |\n| HTML | 网页发布 |\n| PDF | 阅读与分享 |\n\n```markdown\n# 这里是代码，不生成标题节点\n```'**
  String get sampleDesign;

  /// No description provided for @sampleWeekly.
  ///
  /// In zh, this message translates to:
  /// **'# 每周复盘\n\n## 本周进展\n\n- [x] 确认三个主要视图\n- [ ] 收集实际使用反馈\n\n## 下周计划\n\n把结构梳理融入日常 Markdown 写作。'**
  String get sampleWeekly;

  /// No description provided for @sampleReading.
  ///
  /// In zh, this message translates to:
  /// **'# 读书摘录\n\n## 写作就是思考\n\n写下来，才能看清一个想法里缺失的环节。\n\n> 好的工具应该让想法更清楚。\n\n## 从笔记到文章\n\n### 收集素材\n\n先保留原始材料与出处。\n\n### 整理结构\n\n把相近的观点放在一起，先确定层级，再补充论据。'**
  String get sampleReading;

  /// No description provided for @sampleStart.
  ///
  /// In zh, this message translates to:
  /// **'# 快速开始\n\n## 编辑\n\n点击正文直接编辑，或切换源码。所有视图共享同一份内容与撤销历史。\n\n## 阅读\n\n八套配色、六套排版，与内容独立保存。\n\n## 导图\n\n双击节点编辑章节；长按拖到另一个章节可调整层级。\n\n## 本地文件\n\n从文件菜单打开自己的 Markdown。使用 Ctrl+S 保存。未保存内容会保留恢复草稿。'**
  String get sampleStart;

  /// No description provided for @sampleExport.
  ///
  /// In zh, this message translates to:
  /// **'# 导出指南\n\n## Markdown\n\n保存为标准 UTF-8 文本，其他编辑器也可继续使用。\n\n## HTML\n\n导出包含当前排版与配色的独立页面。\n\n## PDF 与 Word\n\n导出用于阅读与分享的文档。\n\n## 导图图片\n\n导出完整树形结构的 PNG。'**
  String get sampleExport;

  /// No description provided for @guideDocument.
  ///
  /// In zh, this message translates to:
  /// **'# 欢迎使用笺纬\n\n点击正文，写下第一个想法。\n\n## 从内容到结构\n\n在导图中整理章节，正文会同步变化。\n\n## 分享你的作品\n\n选择排版，把内容导出为文档。'**
  String get guideDocument;

  /// No description provided for @presentationOutline.
  ///
  /// In zh, this message translates to:
  /// **'演示大纲'**
  String get presentationOutline;

  /// No description provided for @presentationPrevious.
  ///
  /// In zh, this message translates to:
  /// **'上一页'**
  String get presentationPrevious;

  /// No description provided for @presentationNext.
  ///
  /// In zh, this message translates to:
  /// **'下一页'**
  String get presentationNext;

  /// No description provided for @presentationSmaller.
  ///
  /// In zh, this message translates to:
  /// **'减小演示字号'**
  String get presentationSmaller;

  /// No description provided for @presentationLarger.
  ///
  /// In zh, this message translates to:
  /// **'增大演示字号'**
  String get presentationLarger;

  /// No description provided for @presentationKeys.
  ///
  /// In zh, this message translates to:
  /// **'← / →、PageUp / PageDown 翻页 · Home / End 首尾页 · Esc 退出'**
  String get presentationKeys;

  /// No description provided for @presentationMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get presentationMarkdown;

  /// No description provided for @mcpSettings.
  ///
  /// In zh, this message translates to:
  /// **'MCP 设置'**
  String get mcpSettings;

  /// No description provided for @mcpIntro.
  ///
  /// In zh, this message translates to:
  /// **'允许 AI 客户端通过本机 MCP 接口读取和操作当前文档。'**
  String get mcpIntro;

  /// No description provided for @mcpEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用 MCP Server'**
  String get mcpEnable;

  /// No description provided for @mcpAddress.
  ///
  /// In zh, this message translates to:
  /// **'监听地址'**
  String get mcpAddress;

  /// No description provided for @mcpPort.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get mcpPort;

  /// No description provided for @mcpToken.
  ///
  /// In zh, this message translates to:
  /// **'授权 Token'**
  String get mcpToken;

  /// No description provided for @mcpGenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get mcpGenerate;

  /// No description provided for @mcpCopyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get mcpCopyAddress;

  /// No description provided for @mcpScope.
  ///
  /// In zh, this message translates to:
  /// **'允许访问范围'**
  String get mcpScope;

  /// No description provided for @mcpDocument.
  ///
  /// In zh, this message translates to:
  /// **'仅当前文档'**
  String get mcpDocument;

  /// No description provided for @mcpFolder.
  ///
  /// In zh, this message translates to:
  /// **'当前打开文件夹'**
  String get mcpFolder;

  /// No description provided for @mcpCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义目录'**
  String get mcpCustom;

  /// No description provided for @mcpConfirm.
  ///
  /// In zh, this message translates to:
  /// **'修改、保存或打开文件前需要确认'**
  String get mcpConfirm;

  /// No description provided for @mcpRunning.
  ///
  /// In zh, this message translates to:
  /// **'服务运行中'**
  String get mcpRunning;

  /// No description provided for @mcpStopped.
  ///
  /// In zh, this message translates to:
  /// **'未启动'**
  String get mcpStopped;

  /// No description provided for @mcpConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认 MCP 操作'**
  String get mcpConfirmTitle;

  /// No description provided for @mcpConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'AI 客户端请求执行以下操作。执行后可通过撤销恢复文档修改。'**
  String get mcpConfirmBody;

  /// No description provided for @mcpExecute.
  ///
  /// In zh, this message translates to:
  /// **'执行'**
  String get mcpExecute;

  /// No description provided for @mcpInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1024–65535 的端口和至少 24 位的 Token。'**
  String get mcpInvalid;

  /// No description provided for @openRecent.
  ///
  /// In zh, this message translates to:
  /// **'打开最近文件'**
  String get openRecent;

  /// No description provided for @saveAllDocuments.
  ///
  /// In zh, this message translates to:
  /// **'保存全部'**
  String get saveAllDocuments;

  /// No description provided for @fullscreen.
  ///
  /// In zh, this message translates to:
  /// **'切换全屏'**
  String get fullscreen;

  /// No description provided for @actualSize.
  ///
  /// In zh, this message translates to:
  /// **'实际大小'**
  String get actualSize;

  /// No description provided for @menuNavigation.
  ///
  /// In zh, this message translates to:
  /// **'文档导航'**
  String get menuNavigation;

  /// No description provided for @menuWindow.
  ///
  /// In zh, this message translates to:
  /// **'窗口'**
  String get menuWindow;

  /// No description provided for @closeDocument.
  ///
  /// In zh, this message translates to:
  /// **'关闭文档'**
  String get closeDocument;

  /// No description provided for @documentProperties.
  ///
  /// In zh, this message translates to:
  /// **'文档属性'**
  String get documentProperties;

  /// No description provided for @mcpAudit.
  ///
  /// In zh, this message translates to:
  /// **'MCP 审计'**
  String get mcpAudit;

  /// No description provided for @mcpAuditEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无操作记录'**
  String get mcpAuditEmpty;

  /// No description provided for @noRecent.
  ///
  /// In zh, this message translates to:
  /// **'暂无最近文件'**
  String get noRecent;

  /// No description provided for @clearRecent.
  ///
  /// In zh, this message translates to:
  /// **'清空最近记录'**
  String get clearRecent;

  /// No description provided for @officialWebsite.
  ///
  /// In zh, this message translates to:
  /// **'官方网站'**
  String get officialWebsite;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'反馈'**
  String get feedback;

  /// No description provided for @printPreview.
  ///
  /// In zh, this message translates to:
  /// **'打印预览'**
  String get printPreview;

  /// No description provided for @strike.
  ///
  /// In zh, this message translates to:
  /// **'删除线'**
  String get strike;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
