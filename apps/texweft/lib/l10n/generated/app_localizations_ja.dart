// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

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
  String get appearance => '外観と書式';

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
  String get settings => '設定';

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
  String get appTitle => 'Texweft';

  @override
  String get checking => '確認中…';

  @override
  String get noRelease => '正式版はまだ公開されていません。';

  @override
  String get githubUnavailable => 'GitHub に接続できません。しばらくしてから再試行してください。';

  @override
  String get about => 'Texweft について';

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
  String get typographyHint => '6 種類のスタイル・配色とは個別に設定';

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
  String get documentChanged => '文書が変更されました。表の挿入位置を選び直してください。';

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
  String get guideViewsTitle => 'ふたつの表示、ひとつの文書';

  @override
  String get guideViewsBody => '左でソースを編集し、右で本文をすぐに確認できます。見出しを追加してみましょう。';

  @override
  String get guideMapTitle => '文章のつながりを見る';

  @override
  String get guideMapBody => 'マップには節と要約が表示されます。移動、枝の折りたたみ、節のダブルクリックを試してください。';

  @override
  String get guideArrangeTitle => '節を直接整理する';

  @override
  String get guideArrangeBody => '節の追加・構成ツールで見出し、本文、順序、階層を変更できます。変更はすべて元に戻せます。';

  @override
  String get guideTypographyTitle => '文章に合う書式を選ぶ';

  @override
  String get guideTypographyBody =>
      '書式パネルで 6 種類のスタイルを比較できます。配色や書式を変えても原文は変わりません。';

  @override
  String get guideFinishTitle => '自分の文章を書き始める';

  @override
  String get guideFinishBody =>
      'ガイド終了後は元の内容と履歴に戻ります。その後、自分の文書を開くか、新しく作成してください。';

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
  String cursorPosition(int line, int column) {
    final intl.NumberFormat lineNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String lineString = lineNumberFormat.format(line);
    final intl.NumberFormat columnNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String columnString = columnNumberFormat.format(column);

    return '$lineString 行、$columnString 列';
  }

  @override
  String characterCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString 文字';
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
      '# Texweft へようこそ\n\n本文をクリックして最初のアイデアを書いてみましょう。\n\n## 内容から構造へ\n\nマップで節を整理すると本文にも反映されます。\n\n## 作品を共有する\n\n書式を選んで文書を書き出します。';
}
