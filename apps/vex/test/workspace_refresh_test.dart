import 'package:flutter_test/flutter_test.dart';
import 'package:vex/domain/workspace.dart';

import 'support/fakes.dart';

void main() {
  test(
    'chapter jumps leave hidden map pending and retain its selection on show',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final map = vm.map, root = map.root;
      vm.editor.session.replace('# Root\n\n## Target\n\nBody');
      final heading = vm.editor.document.headings.last;
      vm.selectHeading(heading);
      expect(map.root, same(root));
      expect(vm.editor.navigation.value!.selection.start, heading.header.start);
      vm.setLayout(WorkspaceLayout.instantMap);
      expect(map.root.title, 'Root');
      expect(map.selectedId, heading.id);
      vm.setLayout(WorkspaceLayout.instant);
      vm.editor.session.replace('# Changed\n\n## Target\n\nBody');
      final previous = map.root;
      vm.followAnchor('#');
      expect(map.root, same(previous));
      vm.setLayout(WorkspaceLayout.instantMap);
      expect(map.root.title, 'Changed');
      expect(map.selectedId, isNull);
    },
  );

  test('hidden map defers parsing and layout across consecutive edits', () {
    final vm = fakeWorkspace();
    addTearDown(vm.dispose);
    final map = vm.map, initialRoot = vm.map.root;
    var mapChanges = 0, workspaceChanges = 0;
    map.addListener(() => mapChanges++);
    vm.addListener(() => workspaceChanges++);

    for (var i = 0; i < 10; i++) {
      vm.editor.session.replace('# Heading $i\n\nBody $i');
    }

    expect(map.root, same(initialRoot));
    expect(mapChanges, 0);
    expect(workspaceChanges, 10);
    expect(vm.map, same(map));
    expect(map.root.title, 'Heading 9');
    expect(mapChanges, 1);
  });

  test(
    'showing the map flushes pending edits before workspace listeners run',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final map = vm.map;
      vm.editor.session.replace('# Latest title');
      final observedTitles = <String>[];
      vm.addListener(() => observedTitles.add(map.root.title));

      vm.setLayout(WorkspaceLayout.instantMap);

      expect(observedTitles, isNotEmpty);
      expect(observedTitles, everyElement('Latest title'));
      vm.editor.session.replace('# Updated again');
      expect(map.root.title, 'Updated again');
      final root = map.root;
      vm.editor.select(4);
      expect(map.root, same(root));
    },
  );

  test(
    'hidden changes still refresh search results and deferred summaries',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      final map = vm.map;
      vm.search('match');
      vm.editor.session.replace('# Title\n\nmatch match');
      expect(vm.matches, hasLength(2));
      vm.setSummary(length: 5);

      expect(vm.map.root.children.single.title, 'match…');
      expect(map, same(vm.map));
      vm.editor.session.undo();
      expect(vm.matches, isEmpty);
      expect(vm.map.root.children, isEmpty);
    },
  );

  test(
    'closing find clears the query so typing no longer refreshes matches',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.search('match');
      vm.editor.session.replace(
        '# Title'
        '\\n\\n'
        'match match',
      );
      expect(vm.matches, hasLength(2));
      vm.closeFind();
      expect(vm.findQuery, isEmpty);
      expect(vm.matches, isEmpty);
      vm.editor.session.replace(
        '# Title'
        '\\n\\n'
        'match match match',
      );
      expect(vm.matches, isEmpty);
      // 重新打开查找栏时按当前内容重新刷新。
      vm.search('match');
      vm.showFind();
      expect(vm.matches, hasLength(3));
    },
  );

  test(
    'switching hidden documents rebuilds the map for the current document only',
    () {
      final vm = fakeWorkspace();
      addTearDown(vm.dispose);
      vm.editor.session.replace('# First');
      final first = vm.current;
      final map = vm.map;
      vm.newDocument();
      vm.editor.session.replace('# Second');
      vm.switchDocument(first);

      expect(map.root.title, 'First');
      expect(vm.map.root.id, first.id);
      expect(vm.map.root.title, 'First');
      expect(vm.editor.session.isDirty, isTrue);
    },
  );
}
