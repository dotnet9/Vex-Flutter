import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:texweft_markdown_core/texweft_markdown_core.dart';

import '../../data/services/mcp_server.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/palette_tokens.dart';
import 'workspace_view_model.dart';

final class WorkspaceMcp extends ChangeNotifier {
  WorkspaceMcp(this.vm) {
    server = McpServer(tools: tools, dispatch: dispatch);
  }
  final WorkspaceViewModel vm;
  late final McpServer server;
  bool enabled = false,
      requireConfirmation = true,
      _mutating = false,
      _disposed = false;
  int port = 17891;
  String token = McpServer.generateToken(),
      scope = 'document',
      customFolder = '',
      error = '';
  Future<bool> Function(String name)? confirm;
  final audit = <Map<String, String>>[];
  int _configurationRevision = 0;
  static const _documentActions = {
    'get_document',
    'get_outline',
    'get_selection',
    'replace_document',
    'apply_text_edit',
    'insert_text',
    'replace_selection',
    'replace_text',
    'save_document',
    'undo',
    'redo',
  };
  Map<String, Object?> get preferences => {
    'enabled': enabled,
    'port': port,
    'token': token,
    'scope': scope,
    'customFolder': customFolder,
    'confirm': requireConfirmation,
  };
  Future<void> load(Object? value) async {
    if (value is! Map) return;
    port = (value['port'] as int? ?? 17891).clamp(1024, 65535);
    if (value['token'] is String && (value['token'] as String).length >= 24) {
      token = value['token'] as String;
    }
    scope = ['document', 'folder', 'custom'].contains(value['scope'])
        ? value['scope'] as String
        : 'document';
    customFolder = value['customFolder'] as String? ?? '';
    requireConfirmation = value['confirm'] != false;
    await configure(value['enabled'] == true, persist: false);
  }

  Future<void> configure(bool value, {bool persist = true}) async {
    if (_disposed) throw StateError('The workspace has closed');
    final configuration = ++_configurationRevision;
    enabled = value;
    error = '';
    var failure = '';
    try {
      if (value) {
        await server.start(port: port, token: token);
      } else {
        await server.stop();
      }
    } catch (e) {
      failure = e.toString();
    }
    if (_disposed || configuration != _configurationRevision) return;
    error = failure;
    if (persist) vm.persist();
    if (!_disposed) notifyListeners();
  }

  Future<void> _checkPath(String path) async {
    if (!p.isAbsolute(path)) {
      throw ArgumentError('An absolute local path is required');
    }
    final resolved = await File(path).resolveSymbolicLinks();
    final current = vm.current.path;
    if (scope == 'document') {
      if (current == null ||
          !p.equals(resolved, await File(current).resolveSymbolicLinks())) {
        throw StateError('The requested file is outside the allowed scope');
      }
      return;
    }
    final directory = scope == 'custom'
        ? customFolder
        : vm.folder != null
        ? vm.folder!.path
        : current == null
        ? ''
        : p.dirname(current);
    if (directory.isEmpty) throw StateError('No workspace folder is open');
    final root = await Directory(directory).resolveSymbolicLinks();
    if (!p.isWithin(root, resolved)) {
      throw StateError('The requested file is outside the allowed scope');
    }
  }

  Future<Object?> dispatch(String name, Map<String, Object?> args) async {
    if (_disposed) throw StateError('The workspace has closed');
    final configuration = _configurationRevision;
    final access = (scope, customFolder, vm.folder?.path);
    void checkConfiguration() {
      if (_disposed ||
          configuration != _configurationRevision ||
          access != (scope, customFolder, vm.folder?.path)) {
        throw StateError('MCP access settings changed; send a new request');
      }
    }

    final action = name.replaceFirst('texweft_', '');
    if (scope != 'document' && _documentActions.contains(action)) {
      final path = vm.current.path;
      if (path == null) {
        throw StateError(
          'The current document has no path inside the allowed folder',
        );
      }
      await _checkPath(path);
    }
    checkConfiguration();
    final reading = {
      'get_document',
      'get_outline',
      'get_selection',
      'list_files',
      'get_app_status',
      'get_operation_audit',
      'ui_get_state',
    };
    if (reading.contains(action)) {
      final result = await _read(action);
      checkConfiguration();
      return result;
    }
    if (_mutating) {
      throw StateError('Another MCP operation is awaiting completion');
    }
    if (vm.guiding) {
      throw StateError(
        'Finish the guide before changing documents through MCP',
      );
    }
    _mutating = true;
    final document = vm.current, revision = vm.editor.session.revision;
    try {
      if (requireConfirmation && !(await confirm?.call(name) ?? false)) {
        throw StateError('Operation declined');
      }
      checkConfiguration();
      if (_disposed ||
          !identical(vm.current, document) ||
          vm.editor.session.revision != revision) {
        throw StateError(
          'The document changed while the operation was pending; read it again',
        );
      }
      final expected = args['revision'];
      if (expected != null && expected != revision) {
        throw StateError('Document revision does not match');
      }
      final editor = vm.editor;
      String string(String key) {
        final value = args[key];
        if (value is! String) throw ArgumentError('Missing string: $key');
        return value;
      }

      int offset(String key, int fallback) {
        final value = args[key] ?? fallback;
        if (value is! int || value < 0 || value > editor.text.length) {
          throw ArgumentError('Invalid offset: $key');
        }
        return value;
      }

      switch (action) {
        case 'replace_document':
          editor.session.replace(string('text'), label: 'MCP 替换全文');
        case 'apply_text_edit':
          final start = offset('offset', 0), length = args['length'];
          if (length is! int ||
              length < 0 ||
              start + length > editor.text.length) {
            throw ArgumentError('Invalid length');
          }
          editor.session.patch(
            TextPatch(SourceRange(start, start + length), string('text')),
            label: 'MCP 修改文本',
          );
        case 'insert_text':
          final start = offset('offset', editor.text.length);
          editor.session.patch(
            TextPatch(SourceRange(start, start), string('text')),
            label: 'MCP 插入文本',
          );
        case 'replace_selection':
          editor.replaceSelection(string('text'), label: 'MCP 替换选区');
        case 'replace_text':
          final query = string('query'),
              matches = editor.find(query, caseSensitive: true);
          if (query.isEmpty ||
              matches.isEmpty ||
              (matches.length != 1 && args['replace_all'] != true)) {
            throw StateError(
              'Text must match uniquely or replace_all must be true',
            );
          }
          editor.replaceAll(query, string('text'), caseSensitive: true);
        case 'open_document':
          final path = string('path');
          await _checkPath(path);
          await vm.openPath(path);
        case 'save_document':
          if (!await vm.save()) throw StateError('Save was cancelled');
        case 'undo':
          editor.session.undo();
        case 'redo':
          editor.session.redo();
        case 'ui_set_layout':
          final layout = WorkspaceLayout.values
              .where((v) => v.name == args['layout'])
              .firstOrNull;
          if (layout == null) throw ArgumentError('Unknown layout');
          vm.setLayout(layout);
        case 'ui_set_theme':
          final palette = string('palette');
          if (!paletteNames.containsKey(palette)) {
            throw ArgumentError('Unknown palette');
          }
          vm.updateAppearance(palette: palette);
        case 'ui_set_language':
          final language = string('language');
          if (!languageNames.containsKey(language)) {
            throw ArgumentError('Unknown language');
          }
          vm.updateAppearance(language: language);
        case 'ui_show_sidebar_tab':
          final tab = string('tab');
          if (!['files', 'outline'].contains(tab)) {
            throw ArgumentError('Unknown tab');
          }
          if (!vm.sidebar) vm.toggleSidebar();
          vm.setOutline(tab == 'outline');
        default:
          throw ArgumentError('Unknown tool');
      }
      _record(name, 'completed');
      return {'ok': true, 'revision': vm.editor.session.revision};
    } catch (_) {
      _record(name, 'declined or failed');
      rethrow;
    } finally {
      _mutating = false;
    }
  }

  Future<Object?> _read(String action) async {
    if (action == 'list_files') {
      final visible = <Map<String, String?>>[];
      for (final doc in vm.documents) {
        if (scope == 'document') {
          if (!identical(doc, vm.current)) continue;
        } else {
          if (doc.path == null) continue;
          try {
            await _checkPath(doc.path!);
          } on FileSystemException {
            continue;
          } on StateError {
            continue;
          }
        }
        visible.add({'name': doc.name, 'path': doc.path});
      }
      return visible;
    }
    final editor = vm.editor;
    return switch (action) {
      'get_document' => {
        'text': editor.text,
        'path': vm.current.path,
        'name': vm.current.name,
        'dirty': editor.session.isDirty,
        'revision': editor.session.revision,
      },
      'get_outline' => [
        for (final h in editor.document.headings)
          {
            'id': h.id,
            'title': h.title,
            'level': h.level,
            'offset': h.header.start,
          },
      ],
      'get_selection' => {
        'start': editor.selection.start,
        'end': editor.selection.end,
        'text': editor.selection.isValid
            ? editor.selection.textInside(editor.text)
            : '',
      },
      'get_operation_audit' => List.of(audit),
      _ => {
        'name': 'Vex',
        'layout': vm.layout.name,
        'palette': vm.palette,
        'language': vm.language,
        'sidebar': vm.sidebar,
        'outline': vm.outline,
        'revision': editor.session.revision,
      },
    };
  }

  void _record(String name, String result) {
    audit.insert(0, {
      'time': DateTime.now().toUtc().toIso8601String(),
      'tool': name,
      'result': result,
    });
    if (audit.length > 100) audit.removeLast();
    if (!_disposed) notifyListeners();
  }

  static List<Map<String, Object?>> get tools => [
    for (final (name, description, properties, required)
        in <(String, String, Map<String, Object?>, List<String>)>[
          (
            'get_document',
            'Read the current document and its revision.',
            {},
            [],
          ),
          ('get_outline', 'Read heading titles and source offsets.', {}, []),
          ('get_selection', 'Read the current editor selection.', {}, []),
          (
            'list_files',
            'List open documents inside the configured access scope.',
            {},
            [],
          ),
          ('get_app_status', 'Read the application state.', {}, []),
          (
            'get_operation_audit',
            'Read recent operation results without document text.',
            {},
            [],
          ),
          ('ui_get_state', 'Read layout and appearance.', {}, []),
          (
            'replace_document',
            'Replace the full document after confirmation.',
            {
              'text': {'type': 'string'},
            },
            ['text'],
          ),
          (
            'apply_text_edit',
            'Replace length UTF-16 code units at offset.',
            {
              'offset': {'type': 'integer'},
              'length': {'type': 'integer'},
              'text': {'type': 'string'},
            },
            ['offset', 'length', 'text'],
          ),
          (
            'insert_text',
            'Insert text at an optional UTF-16 offset.',
            {
              'offset': {'type': 'integer'},
              'text': {'type': 'string'},
            },
            ['text'],
          ),
          (
            'replace_selection',
            'Replace the selected text.',
            {
              'text': {'type': 'string'},
            },
            ['text'],
          ),
          (
            'replace_text',
            'Replace a unique match or every exact match.',
            {
              'query': {'type': 'string'},
              'text': {'type': 'string'},
              'replace_all': {'type': 'boolean'},
            },
            ['query', 'text'],
          ),
          (
            'open_document',
            'Open an existing file inside the configured scope.',
            {
              'path': {'type': 'string'},
            },
            ['path'],
          ),
          (
            'save_document',
            'Save through the normal file service and conflict checks.',
            {},
            [],
          ),
          ('undo', 'Undo one document operation.', {}, []),
          ('redo', 'Redo one document operation.', {}, []),
          (
            'ui_set_layout',
            'Select a workspace layout.',
            {
              'layout': {'type': 'string'},
            },
            ['layout'],
          ),
          (
            'ui_set_theme',
            'Select an interface palette.',
            {
              'palette': {'type': 'string'},
            },
            ['palette'],
          ),
          (
            'ui_set_language',
            'Select an interface language.',
            {
              'language': {'type': 'string'},
            },
            ['language'],
          ),
          (
            'ui_show_sidebar_tab',
            'Select files or outline.',
            {
              'tab': {'type': 'string'},
            },
            ['tab'],
          ),
        ])
      {
        'name': 'texweft_$name',
        'description': description,
        'inputSchema': {
          'type': 'object',
          'properties': {
            ...properties,
            'revision': {'type': 'integer'},
          },
          'required': required,
          'additionalProperties': false,
        },
      },
  ];
  @override
  void dispose() {
    _disposed = true;
    _configurationRevision++;
    confirm = null;
    server.stop();
    super.dispose();
  }
}
