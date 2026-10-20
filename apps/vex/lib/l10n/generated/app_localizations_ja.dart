// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get updateDownload => '更新をダウンロード';

  @override
  String get updateDownloadPrompt =>
      'この端末用のインストーラーをダウンロードします。検証後、任意のタイミングでインストールできます。';

  @override
  String get updateDownloading => 'ダウンロード中…';

  @override
  String get updateVerified => 'インストーラーを検証しました。文書は変更されません。';

  @override
  String get updateInstall => 'インストール';

  @override
  String get updateOpeningInstaller => 'インストーラーを起動中…';

  @override
  String get updateRetry => '再ダウンロード';

  @override
  String get updateDownloadError =>
      'ダウンロードできませんでした。接続を確認して再試行してください。文書は変更されません。';

  @override
  String get updateIntegrityError => 'インストーラーの検証に失敗したため停止しました。再ダウンロードしてください。';

  @override
  String get updateInstallError =>
      'インストーラーを準備できませんでした。Vex は開いたままです。再試行するか、バージョンのリンクから手動でインストールしてください。';

  @override
  String get updateInstallPermission =>
      'システム設定で Vex のアプリインストールを許可し、戻ってインストールを選択してください。';

  @override
  String get preferencesUnavailable =>
      '設定または復元用下書きを読み込めませんでした。再起動して再試行してください。元のファイルは上書きされません。';

  @override
  String get typeAcademic => '論文';

  @override
  String get typeJournal => '手記';

  @override
  String get typeHandbook => '手引き';

  @override
  String get typeAcademicNote => '論説 · 控えめな階層';

  @override
  String get typeJournalNote => '日々の記録 · 柔らかい明朝体';

  @override
  String get typeHandbookNote => '操作資料 · 明確な見出し';

  @override
  String get mapAppearance => 'マップの外観';

  @override
  String get mapStructure => '構造';

  @override
  String get mapStyle => 'スタイル';

  @override
  String get mapQuiet => 'シンプル';

  @override
  String get mapColorful => 'カラフル';

  @override
  String get mapOutline => '線枠';

  @override
  String get mapCapsule => 'カプセル';

  @override
  String get mapUnderline => '枝線';

  @override
  String get mapMono => 'モノクロ';

  @override
  String get newWindow => '新しいウィンドウ';

  @override
  String get documentWindow => '現在の文書を新しいウィンドウで開く';

  @override
  String get openInNewWindow => '新しいウィンドウで開く';

  @override
  String get openFileLocation => 'ファイルの場所を開く';

  @override
  String get copyWechat => 'WeChat にコピー';

  @override
  String get copyZhihu => '知乎にコピー';

  @override
  String get copyJuejin => '掘金にコピー';

  @override
  String get copiedForPublishing => 'コピーしました。投稿先に貼り付けできます';

  @override
  String get guideShareTitle => '文章を共有する';

  @override
  String get guideShareBody => 'ツールメニューから WeChat、知乎、掘金にコピーできます。';

  @override
  String get exitTitle => '閉じる前に、アイデアを残しましょう';

  @override
  String get exitBody => '未保存の変更があります。保存するか、下書きを残して後で続けられます。';

  @override
  String get continueWriting => '執筆を続ける';

  @override
  String get builtinThanks => '謝辞';

  @override
  String get changelog => '更新履歴';

  @override
  String get builtinReadOnly => '組み込み文書 · 読み取り専用';

  @override
  String get aboutVersionLabel => 'バージョン';

  @override
  String get aboutAuthorLabel => '作者';

  @override
  String get aboutLicenseLabel => 'ライセンス';

  @override
  String get aboutLinksLabel => 'リンク';

  @override
  String get typewriterMode => 'タイプライターモード';

  @override
  String get mapLayoutRight => '右向きツリー';

  @override
  String get mapLayoutBalanced => '両側バランス';

  @override
  String get mapLayoutRadial => '放射状';

  @override
  String get mapLayoutDown => '下向きツリー';

  @override
  String get mapLayoutOutline => 'アウトライン';

  @override
  String get mapLayoutFishbone => 'フィッシュボーン';

  @override
  String get close => '閉じる';

  @override
  String get insertTable => '表を挿入';

  @override
  String get cancel => 'キャンセル';

  @override
  String get insert => '挿入';

  @override
  String get tableSizeHint => '表のサイズを指定します。最初の行は見出しです。';

  @override
  String get rows => '行数';

  @override
  String get columns => '列数';

  @override
  String get tableRowsHint => '1～100 行（見出しを含む）';

  @override
  String get tableColumnsHint => '1～20 列';

  @override
  String get generating => '生成中…';

  @override
  String get sentToPrinter => 'システムの印刷画面に送信しました。';

  @override
  String get printCancelled => '印刷をキャンセルしました。';

  @override
  String get exportCancelled => '書き出しをキャンセルしました。';

  @override
  String get exportShare => '書き出しと共有';

  @override
  String get exportDescription =>
      '現在の内容を別のファイルに保存します。HTML は配色と書式を保持し、マップ画像は構造全体を含みます。';

  @override
  String get htmlPage => 'HTML ページ';

  @override
  String get pdfDocument => 'PDF 文書';

  @override
  String get wordDocument => 'Word 文書';

  @override
  String get mindMapPng => 'マップ PNG';

  @override
  String get systemPrint => '印刷…';

  @override
  String get copyHtml => 'HTML ソースをコピー';

  @override
  String get htmlCopied => 'HTML ソースをコピーしました。';

  @override
  String get appearance => '外観';

  @override
  String get themeMode => '表示モード';

  @override
  String get light => 'ライト';

  @override
  String get dark => 'ダーク';

  @override
  String get followSystem => 'システムに従う';

  @override
  String get interfaceColors => 'インターフェースの配色';

  @override
  String get bodyTypography => '本文の書式';

  @override
  String get compactSpacing => '行間を狭くする';

  @override
  String get appearancePreservesSource => '書式や配色を変えても Markdown の原文は変わりません。';

  @override
  String get summarySettings => 'マップの要約設定';

  @override
  String get paragraphs => '段落の本文';

  @override
  String get lists => 'リスト';

  @override
  String get quotesCodeTables => '引用・コード・表';

  @override
  String get summaryDescription =>
      '要約はマップの表示にのみ反映されます。ノードを選択すると、節の全文を表示・編集できます。';

  @override
  String get restoreDefaults => '既定値に戻す';

  @override
  String get settings => '環境設定';

  @override
  String get editor => 'エディター';

  @override
  String get sourceLineNumbers => 'ソースの行番号';

  @override
  String get localFiles => 'ローカルファイル';

  @override
  String get localFilesDescription =>
      '編集中は復元用の下書きを保存します。保存時は元のファイルを更新し、外部の変更があれば事前に通知します。モバイル端末ではシステムのファイル選択画面を使います。';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get appTitle => 'Vex';

  @override
  String get checking => '確認中…';

  @override
  String get updateCurrent => '最新の正式版を使用しています。';

  @override
  String updateAvailable(String version) {
    return '新しいバージョン $version が利用できます。';
  }

  @override
  String get updateLocalNewer => '使用中のバージョンは最新の正式版より新しいものです。';

  @override
  String get updateInvalidResponse => 'リリース情報が不完全なため、更新を確認できません。';

  @override
  String get closeChanged =>
      '保存中に新しい入力があったため、ウィンドウを開いたままにしました。確認してから再度閉じてください。';

  @override
  String get noRelease => '正式版はまだ公開されていません。';

  @override
  String get githubUnavailable => 'GitHub に接続できません。しばらくしてから再試行してください。';

  @override
  String get about => 'このアプリについて';

  @override
  String get slogan => '言葉を綴り、思考をかたちに。';

  @override
  String get nativeApplication => 'Flutter ネイティブアプリ';

  @override
  String get aboutDescription =>
      'Markdown の執筆・閲覧・マインドマップをひとつのワークスペースに。内容はオープンなファイル形式でローカルに保存されます。';

  @override
  String get author => '沙漠尽头的狼 / CodeWF';

  @override
  String get authorWebsite => '作者のウェブサイト';

  @override
  String get githubSource => 'GitHub のソースコード';

  @override
  String get releasesDownloads => 'リリースとダウンロード';

  @override
  String get checkUpdates => '更新を確認';

  @override
  String get acknowledgements =>
      'Flutter、Dart、flutter_markdown_plus、markdown、ファイル・ウィンドウ管理、エクスポート関連のコンポーネント、および Cascadia Code、Noto Sans SC の貢献者に感謝します。各コンポーネントとフォントにはそれぞれのライセンスが適用されます。全文は「オープンソースライセンス」をご覧ください。';

  @override
  String get markdownSource => 'Markdown ソース';

  @override
  String get bodyPreview => '本文プレビュー';

  @override
  String get mindMap => 'マインドマップ';

  @override
  String get instantEditing => 'ライブ編集';

  @override
  String get addSection => '節を追加';

  @override
  String get childSection => '子節';

  @override
  String get arrange => '構成';

  @override
  String get collapse => '折りたたむ';

  @override
  String get summary => '要約設定';

  @override
  String get emptyDocument => 'この文書はまだ空白です。';

  @override
  String get sectionArrangement => '節の構成';

  @override
  String get sectionTitle => '節の見出し';

  @override
  String get moveUp => '上へ移動';

  @override
  String get moveDown => '下へ移動';

  @override
  String get promote => '階層を上げる';

  @override
  String get demote => '階層を下げる';

  @override
  String get sibling => '同じ階層';

  @override
  String get child => '子の階層';

  @override
  String get sectionBody => 'この節の本文';

  @override
  String get sectionBodyHint => 'この節の本文のみを編集します。子節はそのまま保持されます。';

  @override
  String get deleteSection => '節を削除';

  @override
  String get keepBody => '本文を残す';

  @override
  String get deleteWholeSection => '節全体を削除';

  @override
  String get deleteSectionHint => '本文・子節も含めて削除するか、見出しだけを削除します。この操作は元に戻せます。';

  @override
  String get apply => '適用';

  @override
  String get workspaceLayout => 'ワークスペースのレイアウト';

  @override
  String get markdownTypography => 'Markdown の書式';

  @override
  String get closePicker => '選択パネルを閉じる';

  @override
  String get layoutHint => '選択するとすぐに反映されます。すべての表示で同じ内容を共有します。';

  @override
  String get typographyHint => '9 種類のスタイル · 記事全体で読み心地を確認';

  @override
  String get sampleHeading => '言葉をかたちに';

  @override
  String get unsavedContent => '未保存の変更があります';

  @override
  String get keepDraftClose => '下書きを保持して閉じる';

  @override
  String get saveAll => 'すべて保存';

  @override
  String get imageMarkdown => '![画像の説明](画像のパス)';

  @override
  String get documentChanged => '文書が変更されました。メニューを開き直すか、挿入位置を選び直してください。';

  @override
  String get restore => '復元';

  @override
  String get discard => '破棄';

  @override
  String get externalChange => '別のアプリでファイルが変更されました';

  @override
  String get reload => '再読み込み';

  @override
  String get loadExternalChanges => '外部の変更を読み込む';

  @override
  String get load => '読み込む';

  @override
  String get loadExternalHint => '外部ファイルを読み込みますか？現在の変更は「元に戻す」で復元できます。';

  @override
  String get saveCurrentAs => '現在の内容を別名で保存…';

  @override
  String get exitPresentation => 'プレゼンテーションを終了';

  @override
  String get dropMarkdown => 'ドロップして Markdown を開く';

  @override
  String get menuFile => 'ファイル';

  @override
  String get newDocument => '新規文書';

  @override
  String get open => '開く…';

  @override
  String get openFolder => 'フォルダーを開く…';

  @override
  String get save => '保存';

  @override
  String get saveAs => '名前を付けて保存…';

  @override
  String get exportShareMenu => '書き出しと共有…';

  @override
  String get exit => '終了';

  @override
  String get menuEdit => '編集';

  @override
  String get undo => '元に戻す';

  @override
  String get redo => 'やり直す';

  @override
  String get cut => '切り取り';

  @override
  String get copy => 'コピー';

  @override
  String get paste => '貼り付け';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get find => '検索';

  @override
  String get replace => '置換';

  @override
  String get menuInsert => '挿入';

  @override
  String get heading => '見出し';

  @override
  String get quote => '引用';

  @override
  String get link => 'リンク';

  @override
  String get image => '画像';

  @override
  String get codeBlock => 'コードブロック';

  @override
  String get table => '表';

  @override
  String get horizontalRule => '水平線';

  @override
  String get menuView => '表示';

  @override
  String get workspaceLayoutMenu => 'レイアウト…';

  @override
  String get toggleSidebar => 'サイドバーの表示切替';

  @override
  String get focusMode => '集中モード';

  @override
  String get presentationMode => 'プレゼンテーション';

  @override
  String get appearanceMenu => '外観と書式…';

  @override
  String get menuTools => 'ツール';

  @override
  String get menuHelp => 'ヘルプ';

  @override
  String get quickStart => '使い方ガイド';

  @override
  String get aboutUpdates => 'アプリ情報 / 更新を確認';

  @override
  String get toggleTheme => 'ライト・ダークの切替';

  @override
  String get minimize => '最小化';

  @override
  String get maximizeRestore => '最大化 / 元のサイズ';

  @override
  String get filesOutline => 'ファイルとアウトライン';

  @override
  String get quickStartBadge => '• 使い方ガイド';

  @override
  String get layoutDropdown => 'レイアウト';

  @override
  String get findTooltip => '検索 · Ctrl+F';

  @override
  String get saveTooltip => '保存 · Ctrl+S';

  @override
  String get newAction => '新規';

  @override
  String get layout => 'レイアウト';

  @override
  String get edit => '編集';

  @override
  String get read => '閲覧';

  @override
  String get map => 'マップ';

  @override
  String get instantRendering => 'ライブ';

  @override
  String get source => 'ソース';

  @override
  String get bold => '太字';

  @override
  String get italic => '斜体';

  @override
  String get unorderedList => '箇条書き';

  @override
  String get orderedList => '番号付きリスト';

  @override
  String get taskList => 'タスクリスト';

  @override
  String get inlineCode => 'インラインコード';

  @override
  String get moreFormatting => 'その他の書式';

  @override
  String get findText => '検索するテキスト';

  @override
  String get matchCase => '大文字と小文字を区別';

  @override
  String get regularExpression => '正規表現';

  @override
  String get wholeWord => '単語全体';

  @override
  String get nextMatch => '次の一致';

  @override
  String get closeFind => '検索を閉じる';

  @override
  String get replaceWith => '置換後の文字列';

  @override
  String get replaceAll => 'すべて置換';

  @override
  String get unsaved => '未保存';

  @override
  String get unmodified => '変更なし';

  @override
  String get writing => '執筆';

  @override
  String get guideWriteTitle => '最初の一文を書いてみる';

  @override
  String get guideWriteBody =>
      '本文をクリックして直接編集できます。ライブ編集とソースは同じ Markdown を共有します。';

  @override
  String get guideViewsTitle => 'ファイルとアウトライン';

  @override
  String get guideViewsBody => 'ファイルで文書を切り替え、アウトラインで節に移動します。見出しを選んでみてください。';

  @override
  String get guideMapTitle => '文章のつながりを見る';

  @override
  String get guideMapBody => 'マップで節を整理し、構造とスタイルを比較します。節をダブルクリックして見出しを変更できます。';

  @override
  String get guideArrangeTitle => '全体を見ながら書く';

  @override
  String get guideArrangeBody =>
      '画面に合う表示の組み合わせを試してください。ソース・本文・マップは同期し、スマートフォンでは単一表示を使います。';

  @override
  String get guideTypographyTitle => '文章に合う書式を選ぶ';

  @override
  String get guideTypographyBody =>
      '9 種類の書式をパネルを閉じずに比較できます。本文書式と画面の配色は独立しています。';

  @override
  String get guideFinishTitle => '保存して持ち出す';

  @override
  String get guideFinishBody =>
      'Markdown を保存したり文書を出力したりできます。練習ではコピーのみ保存し、終了時に元の内容と履歴を復元します。';

  @override
  String get endGuide => 'ガイドを終了';

  @override
  String get previous => '前へ';

  @override
  String get done => '完了';

  @override
  String get next => '次へ';

  @override
  String get files => 'ファイル';

  @override
  String get outline => 'アウトライン';

  @override
  String get documentStructure => '文書の構造';

  @override
  String get outlineHint => '# 見出しで文書を整理しましょう。';

  @override
  String get searchDocuments => '文書を検索…';

  @override
  String get notes => 'ノート';

  @override
  String get openMarkdownFolder => 'Markdown フォルダーを開く';

  @override
  String get recentlyOpened => '最近開いた項目';

  @override
  String get language => '言語';

  @override
  String get languageHint => '表示言語を変更します。文書の内容は変わりません。';

  @override
  String get codeLanguage => 'コードの言語';

  @override
  String get writingPlaceholder => '最初の一文から…';

  @override
  String get newParagraph => '段落を追加';

  @override
  String get zoomOut => '縮小';

  @override
  String get zoomIn => '拡大';

  @override
  String get fitCanvas => '全体を表示';

  @override
  String get expand => '展開';

  @override
  String get untitled => '無題';

  @override
  String get untitledFile => '無題.md';

  @override
  String get emptyFolder => '空のフォルダー';

  @override
  String get recoveredDraftFile => '復元した下書き.md';

  @override
  String get invalidRegex => '正規表現が無効です';

  @override
  String get finishGuideBeforeSaving => 'ガイドを終了してから自分の文書を保存してください。';

  @override
  String get fileConflict => '別のアプリでファイルが変更されました。再読み込みするか別名で保存してください。';

  @override
  String get layoutSourceRender => 'ソース＋プレビュー';

  @override
  String get layoutSourceMap => 'ソース＋マップ';

  @override
  String get layoutInstantMap => 'ライブ＋マップ';

  @override
  String get layoutThree => 'ソース＋プレビュー＋マップ';

  @override
  String get typeSimple => 'シンプル';

  @override
  String get typeDocument => 'ドキュメント';

  @override
  String get typeBook => '書籍';

  @override
  String get typeTechnical => 'テクニカル';

  @override
  String get typeColumn => 'コラム';

  @override
  String get typeEditorial => 'エディトリアル';

  @override
  String get typeSimpleNote => '日々の執筆・ゆったりした余白';

  @override
  String get typeDocumentNote => '知識の整理・明確な区切り';

  @override
  String get typeBookNote => '長文の閲覧・明朝体';

  @override
  String get typeTechnicalNote => '開発ノート・情報ブロック';

  @override
  String get typeColumnNote => '論説・明瞭な階層';

  @override
  String get typeEditorialNote => '公開用・細い段組み';

  @override
  String get paletteWeft => 'ブランドグリーン';

  @override
  String get paletteGraphite => 'グラファイト';

  @override
  String get paletteOcean => 'オーシャン';

  @override
  String get paletteSand => 'サンド';

  @override
  String get paletteRose => 'ローズ';

  @override
  String get paletteIris => 'アイリス';

  @override
  String get paletteOlive => 'オリーブ';

  @override
  String get paletteEmber => 'テラコッタ';

  @override
  String integerRange(int max) {
    final intl.NumberFormat maxNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String maxString = maxNumberFormat.format(max);

    return '1～$maxString の整数を入力してください';
  }

  @override
  String exportedFile(String name) {
    return '$name を書き出しました';
  }

  @override
  String exportFailed(String error) {
    return '書き出しに失敗しました：$error';
  }

  @override
  String summaryLength(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '要約の長さ：$countString 文字';
  }

  @override
  String bodyFontSize(int size) {
    final intl.NumberFormat sizeNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String sizeString = sizeNumberFormat.format(size);

    return '本文の文字サイズ：$sizeString px';
  }

  @override
  String updateHttpError(int code) {
    return '更新を確認できませんでした（HTTP $code）。リリースページをご覧ください。';
  }

  @override
  String latestVersion(String version) {
    return 'GitHub の最新バージョン：$version';
  }

  @override
  String showPaneOnly(String title) {
    return '$title のみ表示';
  }

  @override
  String deleteNamedSection(String title) {
    return '「$title」を削除';
  }

  @override
  String unsavedDocuments(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 件の文書が未保存です。ファイルに保存するか、復元用の下書きを保持して閉じることができます。';
  }

  @override
  String recoveryDraftCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '復元できる下書きが $countString 件あります';
  }

  @override
  String typographyDropdown(String name) {
    return '書式 $name';
  }

  @override
  String matchCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 件の一致';
  }

  @override
  String wordCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 語';
  }

  @override
  String preferencesLoadFailed(String error) {
    return '設定または下書きを読み込めませんでした：$error';
  }

  @override
  String savedFile(String name) {
    return '$name を保存しました';
  }

  @override
  String fileReadFailed(String error) {
    return '元のファイルを読み込めません：$error';
  }

  @override
  String recoverySaveFailed(String error) {
    return '復元用の下書きを保存できませんでした：$error';
  }

  @override
  String preferencesSaveFailed(String error) {
    return '設定を保存できませんでした：$error';
  }

  @override
  String sectionLevel(int level) {
    return 'H$level・節';
  }

  @override
  String get markdownDocument => 'Markdown 文書';

  @override
  String tableColumn(int number) {
    final intl.NumberFormat numberNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String numberString = numberNumberFormat.format(number);

    return '列$numberString';
  }

  @override
  String saveNamedFile(String name) {
    return '$name を保存';
  }

  @override
  String get newSectionTitle => '新しい節';

  @override
  String operationFailed(String error) {
    return '操作に失敗しました：$error';
  }

  @override
  String get sampleDesignName => 'テーマ設計ノート.md';

  @override
  String get sampleWeeklyName => '週次レビュー.md';

  @override
  String get sampleReadingName => '読書ノート.md';

  @override
  String get sampleStartName => 'はじめに.md';

  @override
  String get sampleExportName => '書き出しガイド.md';

  @override
  String get sampleDesign =>
      '# テーマ設計ノート\n\n同じ Markdown を執筆・閲覧し、構造を整理します。表示を切り替えても、注目している内容を見失いません。\n\n## 設計の原則\n\n### 執筆に集中する\n\n内容に集中できるようにします。執筆時は必要なツールを表示し、閲覧や構造の整理では文書により広い空間を使います。\n\n### 視覚的なノイズを減らす\n\n階層、余白、少数のアクセントカラーで関係を表現します。枠線やボタン、通知は控えめにします。\n\n## テーマの配色\n\nライトとダークの両方に対応します。選択・移動・主要な操作にはアクセントを使い、本文のコントラストを安定させます。\n\n- ライトとダークを個別に選択\n- 8 種類の配色で共通の意味を持つトークンを使用\n\n## 書式と文字間隔\n\n読みやすさを優先し、見出しの階層を明確にします。マップの要約は既定で先頭 30 文字を表示します。ノードを選ぶと節の全文を確認できます。\n\n## 書き出しの一貫性\n\n> 同じ内容が、エディター、閲覧表示、書き出したファイルのいずれでも明確な構造を保つことが大切です。\n\n| 形式 | 用途 |\n| --- | --- |\n| HTML | ウェブへの公開 |\n| PDF | 閲覧と共有 |\n\n```markdown\n# これはコードであり、見出しノードにはなりません\n```';

  @override
  String get sampleWeekly =>
      '# 週次レビュー\n\n## 今週の進捗\n\n- [x] 3 つの主要な表示を確認\n- [ ] 実際の利用者から意見を集める\n\n## 来週の計画\n\n日々の Markdown 執筆に構造の整理を取り入れる。';

  @override
  String get sampleReading =>
      '# 読書ノート\n\n## 書くことは考えること\n\n書き出すことで、考えに足りないつながりが見えてきます。\n\n> よい道具は考えを明確にしてくれます。\n\n## ノートから記事へ\n\n### 素材を集める\n\n元の資料と出典を残します。\n\n### 構造を整理する\n\n関連する考えをまとめ、階層を決めてから根拠を補います。';

  @override
  String get sampleStart =>
      '# はじめに\n\n## 編集\n\n本文をクリックして直接編集するか、ソースに切り替えます。すべての表示で内容と履歴を共有します。\n\n## 閲覧\n\n8 種類の配色と 6 種類の書式は、内容とは別に保存されます。\n\n## マップ\n\nノードをダブルクリックすると節を編集できます。長押しして別の節にドラッグすると階層を変更できます。\n\n## ローカルファイル\n\nファイルメニューから Markdown を開きます。Ctrl+S で保存します。未保存の変更は復元用の下書きに残ります。';

  @override
  String get sampleExport =>
      '# 書き出しガイド\n\n## Markdown\n\n標準の UTF-8 テキストで保存し、他のエディターでも編集を続けられます。\n\n## HTML\n\n現在の書式と配色を含む独立したページに書き出します。\n\n## PDF と Word\n\n閲覧・共有用の文書に書き出します。\n\n## マップ画像\n\nツリー構造全体を PNG に書き出します。';

  @override
  String get guideDocument =>
      '# Vex へようこそ\n\n本文をクリックして最初のアイデアを書いてみましょう。\n\n## 内容から構造へ\n\nマップで節を整理すると本文にも反映されます。\n\n## 作品を共有する\n\n書式を選んで文書を書き出します。';

  @override
  String get presentationOutline => 'プレゼンテーションのアウトライン';

  @override
  String get presentationPrevious => '前のスライド';

  @override
  String get presentationNext => '次のスライド';

  @override
  String get presentationSmaller => '文字を小さくする';

  @override
  String get presentationLarger => '文字を大きくする';

  @override
  String get presentationKeys =>
      '← / →、PageUp / PageDown：移動 · Home / End：最初 / 最後 · Esc：終了';

  @override
  String get presentationMarkdown => '本文';

  @override
  String get mcpSettings => 'MCP 設定';

  @override
  String get mcpIntro => 'ローカル MCP 接続から AI クライアントが文書を読み取り、編集できます。';

  @override
  String get mcpEnable => 'MCP サーバーを有効にする';

  @override
  String get mcpAddress => '待受アドレス';

  @override
  String get mcpPort => 'ポート';

  @override
  String get mcpToken => '認証トークン';

  @override
  String get mcpGenerate => '再生成';

  @override
  String get mcpCopyAddress => 'アドレスをコピー';

  @override
  String get mcpScope => 'アクセス範囲';

  @override
  String get mcpDocument => '現在の文書のみ';

  @override
  String get mcpFolder => '現在のフォルダー';

  @override
  String get mcpCustom => '指定フォルダー';

  @override
  String get mcpConfirm => '編集・保存・ファイルを開く前に確認する';

  @override
  String get mcpRunning => 'サーバー稼働中';

  @override
  String get mcpStopped => '停止中';

  @override
  String get mcpConfirmTitle => 'MCP 操作の確認';

  @override
  String get mcpConfirmBody => 'AI クライアントが次の操作を要求しています。文書の編集は元に戻せます。';

  @override
  String get mcpExecute => '実行';

  @override
  String get mcpInvalid => 'ポートは 1024–65535、トークンは 24 文字以上で入力してください。';

  @override
  String get openRecent => '最近使ったファイル';

  @override
  String get saveAllDocuments => 'すべて保存';

  @override
  String get fullscreen => '全画面表示';

  @override
  String get actualSize => '実際のサイズ';

  @override
  String get menuNavigation => '文書ナビゲーション';

  @override
  String get menuWindow => 'ウィンドウ';

  @override
  String get closeDocument => '文書を閉じる';

  @override
  String get documentProperties => '文書のプロパティ';

  @override
  String get mcpAudit => 'MCP 操作履歴';

  @override
  String get mcpAuditEmpty => '操作履歴はありません';

  @override
  String get noRecent => '最近使ったファイルはありません';

  @override
  String get clearRecent => '履歴を消去';

  @override
  String get officialWebsite => '公式サイト';

  @override
  String get feedback => 'フィードバック';

  @override
  String get printPreview => '印刷プレビュー';

  @override
  String get strike => '取り消し線';

  @override
  String get documentWatermark => '透かし';

  @override
  String get watermarkPreview => '本文に表示';

  @override
  String get watermarkExport => '書き出しに透かしを含める';

  @override
  String get watermarkText => '透かしの文字';

  @override
  String get watermarkOpacity => '不透明度';

  @override
  String get prefExport => 'エクスポート';

  @override
  String get prefMcpAudit => '監査';

  @override
  String get prefGeneral => '一般とファイル';

  @override
  String get prefSaveRecovery => '保存と復元';

  @override
  String get prefStartup => '起動時';

  @override
  String get prefEmpty => '空のワークスペース';

  @override
  String get prefRestore => '前回の状態を復元';

  @override
  String get prefAutoSave => '自動保存';

  @override
  String get prefSaveDelay => '入力停止後に保存';

  @override
  String get prefRecovery => '復元用の下書きを保持';

  @override
  String get prefNewDefaults => '新規文書の既定値';

  @override
  String get prefEncoding => '文字コード';

  @override
  String get prefNewline => '改行コード';

  @override
  String get prefFont => '本文フォント';

  @override
  String get prefSystemFont => 'システム既定';

  @override
  String get prefSerifFont => 'セリフ体';

  @override
  String get prefMonoFont => '等幅';

  @override
  String get prefBodySize => '本文サイズ';

  @override
  String get prefCodeSize => 'コードサイズ';

  @override
  String get prefIndent => 'インデント';

  @override
  String get prefAutoPair => '括弧の自動補完';

  @override
  String get prefCodeSource => 'コードとソース';

  @override
  String get prefCodeWrap => 'コードの折り返し';

  @override
  String get prefWriting => '執筆';

  @override
  String get prefImages => '画像';

  @override
  String get prefImageCopy => '挿入時に画像をコピー';

  @override
  String get prefImageRelative => '相対パスを使用';

  @override
  String get prefAssetFolder => 'リソースフォルダー';

  @override
  String get prefFolderError => '.. を含まない相対フォルダーを入力';

  @override
  String get prefZoom => 'コンテンツの拡大率';

  @override
  String get showWordCount => '語数を表示';

  @override
  String get searchOutline => '見出しを検索…';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get noSearchResults => '一致する項目はありません';

  @override
  String get fileTreeView => 'ツリー表示に切り替え';

  @override
  String get fileListView => 'リスト表示に切り替え';

  @override
  String get fileActions => 'ファイル操作';

  @override
  String get revealFolder => 'ファイルマネージャーで表示';

  @override
  String get refreshFolder => 'フォルダーを更新';

  @override
  String get fileSortAscending => 'ファイル名 A → Z';

  @override
  String get fileSortDescending => 'ファイル名 Z → A';

  @override
  String get documentLinkNeedsFile => '相対ファイルリンクを開くには、まずこの文書を保存してください。';

  @override
  String get documentLinkUnavailable =>
      'リンク先の文書を開けません。ファイルの場所とアクセス権限を確認してください。';

  @override
  String get prefMotion => '画面アニメーション';

  @override
  String get prefDefaultFormat => '既定の形式';

  @override
  String get prefDefaultDirectory => '既定のフォルダー';

  @override
  String get prefDocumentDirectory => '文書のフォルダー';

  @override
  String get prefOpenAfterExport => '出力後に開く';

  @override
  String get prefPaper => '用紙サイズ';

  @override
  String get prefMargin => '余白';

  @override
  String get prefHtmlStyle => '現在の書式を保持';

  @override
  String get prefSaved => '設定を保存しました';

  @override
  String get prefSaving => '保存中…';

  @override
  String get prefBack => '設定カテゴリに戻る';

  @override
  String get prefApply => '適用';

  @override
  String get prefMcpServer => 'サーバー';

  @override
  String get prefMcpClients => 'クライアント';

  @override
  String get prefMcpMobile => 'このデバイスでは常駐 MCP サーバーを利用できません。';

  @override
  String get prefMcpReveal => 'トークンの表示切替';

  @override
  String get prefMcpStop => 'サーバーを停止';

  @override
  String get prefMcpCopyConfig => '設定をコピー';

  @override
  String get prefMcpTest => '接続テスト';

  @override
  String get prefMcpConnected => '接続と初期化が完了しました';

  @override
  String get prefMcpNotRunning => '先にサーバーを起動してください';

  @override
  String get prefMcpDirectoryError => '既存のローカル絶対フォルダーを指定してください';

  @override
  String get prefMcpTime => '時刻';

  @override
  String get prefMcpAction => '操作';

  @override
  String get prefMcpResult => '結果';

  @override
  String prefSeconds(int count) {
    return '$count 秒';
  }

  @override
  String get mermaidDiagrams => 'Mermaid 図表';

  @override
  String get mermaidExamples => 'Mermaid のサンプル';

  @override
  String get mermaidSource => 'Mermaid ソース';

  @override
  String get mermaidPreview => '図表プレビュー';

  @override
  String get mermaidUnavailable => 'プレビューを生成できません';

  @override
  String get mermaidError => '図表の構文に誤りがあります。ソースは保持されています。';

  @override
  String get menuParagraph => '段落';

  @override
  String get elementActions => '要素の操作';

  @override
  String get elementOpenLink => 'リンクを開く';

  @override
  String get elementPreviewImage => '画像をプレビュー';

  @override
  String get elementCopyUrl => 'アドレスをコピー';

  @override
  String get elementEditLink => 'リンクを編集…';

  @override
  String get elementEditImage => '画像を置換 / 説明を編集…';

  @override
  String get elementUnlink => 'リンクを解除';

  @override
  String get elementDeleteImage => '画像を削除';

  @override
  String get elementPreview => 'プレビュー';

  @override
  String get elementCopySource => 'ソースをコピー';

  @override
  String get elementEditCode => 'コード / 言語を編集…';

  @override
  String get elementEditMath => '数式を編集…';

  @override
  String get elementEditDiagram => '図のソースを編集…';

  @override
  String get elementExpandDiagram => 'ソースとプレビューを展開';

  @override
  String get elementDeleteBlock => '現在のブロックを削除';

  @override
  String get elementDeleteSelection => '選択した文字を削除';

  @override
  String get elementClipboardAs => '形式を指定してコピー / 貼り付け';

  @override
  String get elementCopyMarkdown => 'Markdown としてコピー';

  @override
  String get elementCopyPlain => 'プレーンテキストとしてコピー';

  @override
  String get elementPastePlain => 'プレーンテキストとして貼り付け';

  @override
  String get elementParagraphType => '段落の種類';

  @override
  String get elementIndent => 'インデントを増やす';

  @override
  String get elementOutdent => 'インデントを減らす';

  @override
  String get elementToggleTask => 'タスクの状態を切り替え';

  @override
  String get elementInsertAbove => '上に段落を挿入';

  @override
  String get elementInsertBelow => '下に段落を挿入';

  @override
  String get elementAddress => 'アドレス';

  @override
  String get elementInvalidAddress => '有効なアドレスを入力してください。';

  @override
  String get elementInvalidLanguage => '言語名に空白やフェンス記号は使用できません。';

  @override
  String get elementDescription => 'テキスト / 説明';

  @override
  String get elementTitle => 'タイトル';

  @override
  String get elementLanguage => '言語';

  @override
  String get elementSource => 'ソース';

  @override
  String get tableRowAbove => '上に行を挿入';

  @override
  String get tableRowBelow => '下に行を挿入';

  @override
  String get tableColumnBefore => '左に列を挿入';

  @override
  String get tableColumnAfter => '右に列を挿入';

  @override
  String get tableRowUp => '行を上へ移動';

  @override
  String get tableRowDown => '行を下へ移動';

  @override
  String get tableColumnLeft => '列を左へ移動';

  @override
  String get tableColumnRight => '列を右へ移動';

  @override
  String get tableAlignLeft => '列を左揃え';

  @override
  String get tableAlignCenter => '列を中央揃え';

  @override
  String get tableAlignRight => '列を右揃え';

  @override
  String get tableDeleteRow => '行を削除';

  @override
  String get tableDeleteColumn => '列を削除';

  @override
  String get tableCopy => '表をコピー';

  @override
  String get tableFormat => '表のソースを整形';

  @override
  String get tableDelete => '表を削除';

  @override
  String get menuFormat => '書式';

  @override
  String get menuMore => 'メニュー';

  @override
  String get menuDisplay => 'エディター表示';

  @override
  String get menuWriting => '執筆支援';

  @override
  String get mathBlock => '数式ブロック';

  @override
  String get footnote => '脚注';

  @override
  String get highlight => 'ハイライト';

  @override
  String get superscript => '上付き';

  @override
  String get subscript => '下付き';

  @override
  String get clearFormatting => '書式をクリア';

  @override
  String get quitApp => 'Vex を終了';

  @override
  String get prefMath => '数式';

  @override
  String get prefChemistry => '化学式';

  @override
  String get prefInlineSyntax => 'インライン構文';

  @override
  String get prefSubscript => '下付き・上付き文字';

  @override
  String get prefHighlight => 'ハイライト';

  @override
  String get prefAutoLink => 'リンクを自動検出';

  @override
  String get prefSoftBreak => '単一改行を表示';

  @override
  String prefSpaces(int count) {
    return '$count スペース';
  }

  @override
  String anchorNotFound(String anchor) {
    return '見出しが見つかりません：$anchor';
  }

  @override
  String get excludeGeneratedFolders => '生成されたフォルダーを除外';

  @override
  String get saveCopy => 'コピーを保存';

  @override
  String get quickOpen => 'クイックオープン…';

  @override
  String get copyAsPlainText => 'プレーンテキストとしてコピー';

  @override
  String get keepWindowOnTop => '常に手前に表示';

  @override
  String get reopenWithEncoding => '文字コードを指定して開き直す';

  @override
  String get deleteDocument => '文書を削除…';

  @override
  String deleteDocumentConfirm(String name) {
    return '「$name」をディスクから削除しますか？';
  }

  @override
  String get deleteDocumentHint => 'ファイルはディスクから完全に削除され、元に戻せません。';

  @override
  String get statisticsTitle => '文字数統計';

  @override
  String get statSourceCharacters => 'ソース文字数';

  @override
  String get statParagraphs => '段落';

  @override
  String statReadingTime(int minutes) {
    return '約 $minutes 分';
  }

  @override
  String get statStatus => '状態';

  @override
  String get statModified => '変更あり';

  @override
  String get propertyName => '名前';

  @override
  String get propertyFormat => '形式';

  @override
  String get propertySize => 'サイズ';

  @override
  String propertyBytes(int count) {
    return '$count バイト';
  }

  @override
  String get propertyLocation => '場所';

  @override
  String get statReadingTimeLabel => '読了時間';

  @override
  String get tocTitle => '目次';

  @override
  String get calloutInfo => '情報';

  @override
  String get calloutWarning => '警告';

  @override
  String get builtinMarkdownSample => 'Markdown機能サンプル';

  @override
  String get collapseAllFiles => 'すべて折りたたむ';

  @override
  String get externalChangeReloaded => '外部変更を自動的に再読み込みしました';

  @override
  String get menuDocumentActions => '文書の操作';

  @override
  String get menuNavigationPanels => 'サイドバーとアウトライン';

  @override
  String get menuEditorDisplay => '編集表示';

  @override
  String get menuZoom => 'ズーム';

  @override
  String get menuTableRows => '行の操作';

  @override
  String get menuTableColumns => '列の操作';

  @override
  String get menuTableAlignment => 'セルの配置';

  @override
  String get typographyPreviewMarkdown =>
      '# 考えを整理し、伝わる文章を書く\n\nよい文章は、答える価値のある問いから始まります。まずアイデアを記録し、次に構成を整理して、最後に一文ずつ磨きます。明確な見出しと適度な余白が、内容に集中できる読み心地を作ります。\n\n## アイデアから記事へ\n\n**見出し** で骨組みを作り、*段落* で説明を広げます。一つの段落には一つの役割を持たせ、主張の近くに具体例や根拠を置きましょう。\n\n> 書くことは、読者との対話です。わかりやすさが、考えを伝える力になります。\n\n### 実践できる執筆の流れ\n\n1. 読者が知りたい問いを明確にする。\n2. 主張ごとに具体例を一つ加える。\n3. 冒頭に戻り、重複した表現を削る。\n\n- 大切な情報を残し、読む負担を減らす。\n- 並列の内容はリストで整理する。\n- `Markdown` で内容に集中する。\n\n## 段階を比較する\n\n| 段階 | 注目する点 | 成果 |\n| --- | --- | --- |\n| 構想 | 問いと目標 | アウトライン |\n| 執筆 | 根拠と詳細 | 下書き |\n| 推敲 | リズムと正確さ | 完成原稿 |\n\n### 再利用できる方法を残す\n\n```python\nsteps = [\'構想\', \'執筆\', \'推敲\']\nfor step in steps:\n    print(step)\n```\n\n見出し、引用、表、本文の間隔を比べてみてください。読みやすい組版は、内容を支え、長い文章にも心地よいリズムを与えます。\n';

  @override
  String get mapHeadingsOnly => '見出しのみ';

  @override
  String get mapCompareSource => 'ソースと比較';

  @override
  String mapSummaryLabel(int count) {
    return '要約 $count 文字';
  }

  @override
  String get mapContentSummary => '本文の要約';

  @override
  String get mapNavigationHint => 'Enter：同階層 · Tab：子階層 · ドラッグで構成を変更';
}
