import 'package:flutter_test/flutter_test.dart';
import 'package:vex/domain/workspace.dart';

import 'support/fakes.dart';

void main() {
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
