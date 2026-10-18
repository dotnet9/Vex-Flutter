import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:vex/data/services/social_copy_service.dart';
import 'package:vex_editor/vex_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = SocialCopyService();
  const source = '# 维刻\n\n## 想法\n\n一段 **粗体** 和 *斜体*。\n\n- 梳理\n- 表达\n';

  test(
    'WeChat carries selected style inline and Zhihu uses minimal style',
    () async {
      for (final platform in [
        PublishingPlatform.wechat,
        PublishingPlatform.zhihu,
      ]) {
        final content = await service.prepare(
          platform: platform,
          source: source,
          title: '维刻',
          typography: MarkdownTypography.technical,
        );
        final fragment = html.parseFragment(content.html!);
        expect(
          fragment.querySelector('section')!.attributes['style'],
          contains('background:#fff'),
        );
        final h2 = fragment.querySelector('h2')!.attributes['style']!;
        expect(
          h2.contains('border-left:3px'),
          platform == PublishingPlatform.wechat,
        );
        expect(fragment.querySelector('strong')!.text, '粗体');
        expect(fragment.querySelectorAll('style,script,meta,head'), isEmpty);
        expect(fragment.querySelectorAll('[class],[id]'), isEmpty);
        expect(content.text, contains('维刻\n'));
        expect(content.text, contains('一段 粗体 和 斜体。'));
        expect(content.text, contains('梳理\n'));
      }
    },
  );

  test('Juejin keeps Markdown bytes and does not render', () async {
    const raw = '# 标题\r\n\r\n```dart\r\nprint("维刻");\r\n```\r\n';
    final content = await service.prepare(
      platform: PublishingPlatform.juejin,
      source: raw,
      title: '草稿',
      typography: MarkdownTypography.book,
    );
    expect(content.text, raw);
    expect(content.html, isNull);
  });

  test(
    'inline cascade keeps specificity, repeated rules and screen styles',
    () {
      final content = SocialCopyService.inlineArticle('''
      <html><head><style>
      body{color:#333;font:14px/2 serif}h2{margin:20px 0;color:#102030}
      .chapter{color:#405060}h2{margin-bottom:5px;color:#708090}
      @media print{h2{color:black}}
      </style></head><body><article><h2 class="chapter">章</h2></article></body></html>
    ''');
      final heading = html.parseFragment(content.html!).querySelector('h2')!;
      final style = heading.attributes['style']!;
      expect(
        style.indexOf('margin:20px 0'),
        lessThan(style.indexOf('margin-bottom:5px')),
      );
      expect(
        style.indexOf('color:#708090'),
        lessThan(style.indexOf('color:#405060')),
      );
      expect(style, isNot(contains('color:black')));
    },
  );

  test('copied content excludes active HTML and local or unsafe URLs', () {
    final content = SocialCopyService.inlineArticle('''
      <html><head><style>p{color:#333}</style></head><body><article>
      <script>secret()</script><style>p{background:url(https://bad)}</style>
      <p onclick="bad()" style="position:fixed;background:url(file:///secret);color:red">文字</p>
      <a href="javascript:bad()">链接</a><a href="file:///secret">本地</a>
      <a href="https://example.com">安全</a><img src="file:///secret" alt="图片">
      </article></body></html>
    ''');
    expect(content.html, isNot(contains('secret')));
    expect(content.html, isNot(contains('onclick')));
    expect(content.html, isNot(contains('position:fixed')));
    expect(content.html, isNot(contains('javascript:')));
    expect(content.html, contains('https://example.com'));
    expect(content.text, contains('图片'));
  });

  test(
    'CF_HTML offsets are UTF-8 byte positions including Chinese and emoji',
    () {
      const fragment = '<section>维刻 &amp; 🌱</section>';
      final bytes = SocialCopyService.windowsHtml(fragment);
      final encoded = utf8.decode(bytes);
      int offset(String name) =>
          int.parse(RegExp('$name:(\\d+)').firstMatch(encoded)!.group(1)!);
      expect(
        utf8.decode(
          bytes.sublist(offset('StartFragment'), offset('EndFragment')),
        ),
        fragment,
      );
      expect(
        utf8.decode(bytes.sublist(offset('StartHTML'), offset('EndHTML'))),
        startsWith('<html>'),
      );
      expect(offset('EndHTML'), bytes.length);
    },
  );

  test(
    'native rich clipboard receives both formats and retries busy only',
    () async {
      const channel = MethodChannel('vex/clipboard');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (calls.length == 1) {
              throw PlatformException(code: 'clipboard_busy');
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await SocialCopyService.write(
        const PublishingContent(text: '维刻', html: '<p>维刻</p>'),
      );
      expect(calls.length, 2);
      expect(calls.last.method, 'writeHtml');
      expect(calls.last.arguments['text'], '维刻');
      expect(calls.last.arguments['html'], '<p>维刻</p>');
      expect(calls.last.arguments['windowsHtml'], isA<Uint8List>());
    },
  );
}
