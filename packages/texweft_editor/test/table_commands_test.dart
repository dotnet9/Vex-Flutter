import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:texweft_editor/texweft_editor.dart';

const sample =
    '| Name | Value |\r\n| :--- | ---: |\r\n| One | a\\|b |\r\n| Two | `x|y` |\r\n| Three | **bold** |\r\n';

void main() {
  test('literal backslashes before a pipe round-trip with caret offsets', () {
    for (final value in [r'a|b', r'a\|b', r'a\\|b', '`x|y`', '中文|value']) {
      final encoded = encodeTableCell(value);
      expect(decodeTableCell(encoded), value);
      for (var offset = 0; offset <= value.length; offset++) {
        expect(
          tableCellDisplayOffset(
            encoded,
            tableCellSourceOffset(encoded, offset),
          ),
          offset,
        );
      }
    }
  });

  testWidgets('moving a column keeps typing focus on the moved cell', (
    tester,
  ) async {
    final editor = MarkdownEditorController(text: sample);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('table-cell-2-1')));
    await tester.pumpAndSettle();
    editor.editTable(
      editor.tableTarget(offset: 0, row: 2, column: 1)!,
      MarkdownTableCommand.columnLeft,
    );
    await tester.pumpAndSettle();
    final moved = tester.widget<TextField>(
      find.byKey(const ValueKey('table-cell-2-0')),
    );
    expect(moved.focusNode!.hasFocus, isTrue);
    expect(
      moved.controller!.selection.textInside(moved.controller!.text),
      '`x|y`',
    );
    tester.testTextInput.enterText('Moved');
    await tester.pumpAndSettle();
    expect(editor.tableTarget(offset: 0)!.table.rows[2], ['Moved', 'Two']);
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
  });
  test(
    'parser retains escapes, code pipes, CRLF and data starting with dashes',
    () {
      final table = MarkdownTable.parse(sample)!;
      expect(table.rows.length, 4);
      expect(table.rows[1][1], r'a\|b');
      expect(table.rows[2][1], '`x|y`');
      expect(table.alignments, [
        MarkdownTableAlignment.left,
        MarkdownTableAlignment.right,
      ]);
      final normalized = table.serialize();
      expect(normalized, contains(r'a\|b'));
      expect(normalized, contains('`x|y`'));
      expect(normalized.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(normalized.endsWith('\r\n'), isTrue);
      const dashes = '| A | B |\n| --- | --- |\n| --- data | value |\n';
      expect(parseTableCells(dashes, 0, dashes.length), hasLength(2));
      expect(MarkdownTable.parse('| A |\n| nope |'), isNull);
      expect(MarkdownTable.parse('| A |\n| --- |\n| too | many |'), isNull);
    },
  );

  test(
    'table boundaries match the prototype and preserve its structural header',
    () {
      final table = MarkdownTable.parse(sample)!;
      for (final command in [
        MarkdownTableCommand.rowAbove,
        MarkdownTableCommand.rowUp,
        MarkdownTableCommand.rowDown,
        MarkdownTableCommand.deleteRow,
      ]) {
        expect(table.can(command, 0, 0), isFalse);
      }
      expect(table.can(MarkdownTableCommand.rowUp, 1, 0), isFalse);
      expect(table.can(MarkdownTableCommand.rowDown, 3, 0), isFalse);
      expect(table.can(MarkdownTableCommand.columnLeft, 1, 0), isFalse);
      expect(table.can(MarkdownTableCommand.columnRight, 1, 1), isFalse);
      final single = MarkdownTable.parse('| A |\n| --- |')!;
      expect(single.can(MarkdownTableCommand.deleteColumn, 0, 0), isFalse);
      expect(table.can(MarkdownTableCommand.rowBelow, 0, 0), isTrue);
    },
  );

  for (final command in MarkdownTableCommand.values.where(
    (command) => command != MarkdownTableCommand.copy,
  )) {
    test('${command.name} keeps surrounding text and is one undo step', () {
      const before = 'Before\r\n\r\n', after = '\r\nAfter';
      const original = '$before$sample$after';
      final editor = MarkdownEditorController(text: original);
      addTearDown(editor.dispose);
      final target = editor.tableTarget(
        offset: before.length,
        row: 2,
        column: command == MarkdownTableCommand.columnRight ? 0 : 1,
      )!;
      editor.editTable(target, command);
      expect(editor.text.startsWith(before), isTrue);
      expect(editor.text.endsWith(after), isTrue);
      if (command == MarkdownTableCommand.delete) {
        expect(editor.text, '$before$after');
      } else {
        final changed = editor.tableTarget()!;
        expect(
          changed.table.rows.first.first,
          const [
                MarkdownTableCommand.columnLeft,
                MarkdownTableCommand.columnRight,
              ].contains(command)
              ? 'Value'
              : 'Name',
        );
        expect(changed.table.columns, switch (command) {
          MarkdownTableCommand.columnBefore ||
          MarkdownTableCommand.columnAfter => 3,
          MarkdownTableCommand.deleteColumn => 1,
          _ => 2,
        });
        expect(changed.table.rows.length, switch (command) {
          MarkdownTableCommand.rowAbove || MarkdownTableCommand.rowBelow => 5,
          MarkdownTableCommand.deleteRow => 3,
          _ => 4,
        });
      }
      editor.session.undo();
      expect(editor.text, original);
      expect(editor.session.canUndo, isFalse);
    });
  }

  test('moved columns carry alignment and text together', () {
    final editor = MarkdownEditorController(text: sample);
    addTearDown(editor.dispose);
    editor.editTable(
      editor.tableTarget(offset: 0, row: 2, column: 1)!,
      MarkdownTableCommand.columnLeft,
    );
    final current = editor.tableTarget()!;
    expect(current.row, 2);
    expect(current.column, 0);
    expect(current.table.alignments, [
      MarkdownTableAlignment.right,
      MarkdownTableAlignment.left,
    ]);
    expect(current.table.rows[2], ['`x|y`', 'Two']);
    expect(editor.selection.textInside(editor.text), '`x|y`');
  });

  test('stale and foreign table targets cannot edit any document', () {
    final editor = MarkdownEditorController(text: sample),
        other = MarkdownEditorController(text: sample);
    addTearDown(editor.dispose);
    addTearDown(other.dispose);
    final target = editor.tableTarget(offset: 0)!;
    expect(
      () => other.editTable(target, MarkdownTableCommand.rowBelow),
      throwsStateError,
    );
    editor.select(editor.text.length);
    editor.replaceSelection('Changed');
    expect(target.isCurrent, isFalse);
    expect(
      () => editor.editTable(target, MarkdownTableCommand.delete),
      throwsStateError,
    );
    expect(other.text, sample);
    expect(editor.text, '${sample}Changed');
  });

  testWidgets(
    'visual alignment matches source and selecting code cells never rewrites escapes',
    (tester) async {
      final editor = MarkdownEditorController(text: sample);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarkdownInstantEditor(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('table-cell-2-1'));
      expect(tester.widget<TextField>(cell).textAlign, TextAlign.right);
      await tester.tap(cell);
      await tester.pump();
      expect(editor.text, sample);
      expect(editor.session.canUndo, isFalse);
      await tester.enterText(cell, '`x|z` and a|b');
      await tester.pump();
      expect(editor.text, contains(r'`x|z` and a\|b'));
      expect(
        editor.selection.extentOffset,
        editor.text.indexOf(r'`x|z` and a\|b') + r'`x|z` and a\|b'.length,
      );
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
    },
  );
}
