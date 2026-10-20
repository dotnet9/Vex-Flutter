import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:vex_markdown_core/vex_markdown_core.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:vex_editor/vex_editor.dart' show MarkdownTypography;
import 'package:vex_mindmap/vex_mindmap.dart' show MindMapLayoutMode;

import '../../data/services/mcp_server.dart';
import '../../data/services/mcp_arguments.dart';
import '../../data/repositories/credential_repository.dart';
import '../../domain/workspace.dart';
import '../../l10n/l10n.dart';
import '../core/palette_tokens.dart';
import 'workspace_view_model.dart';

typedef _McpAccess = ({String scope, String? documentPath, String folder});
typedef McpPreferences = ({
  bool enabled,
  int port,
  String token,
  String scope,
  String folder,
  bool confirmation,
});

final class WorkspaceMcp extends ChangeNotifier {
  WorkspaceMcp(this.vm, {required this.credentials}) {
    server = McpServer(tools: tools, dispatch: dispatch);
  }
  final WorkspaceViewModel vm;
  final CredentialRepository credentials;
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
  int _settingsRevision = 0;
  Timer? _settingsTimer;
  McpPreferences? _pendingSettings;
  Future<void> _settingsWrite = Future.value();
  bool settingsSaving = false;
  bool configuring = false;
  String settingsError = '';

  /// Coalesce text input; switches and selections take effect immediately.
  /// The workspace owns pending writes so closing the settings pane loses none.
  void updatePreferences(McpPreferences value, {bool immediate = false}) {
    if (_disposed) return;
    if (!value.enabled && (enabled || configuring || server.running)) {
      // Stop promptly, including while a previous credential write is pending.
      unawaited(stopFromSettings());
    }
    _settingsRevision++;
    _settingsTimer?.cancel();
    _pendingSettings = value;
    settingsSaving = true;
    settingsError = '';
    notifyListeners();
    if (immediate) {
      unawaited(flushSettings());
    } else {
      _settingsTimer = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(flushSettings()),
      );
    }
  }

  void rejectPreferences(String message) {
    _settingsRevision++;
    _settingsTimer?.cancel();
    _pendingSettings = null;
    settingsSaving = false;
    settingsError = message;
    if (!_disposed) notifyListeners();
  }

  Future<void> stopFromSettings({String validationError = ''}) {
    _settingsTimer?.cancel();
    _pendingSettings = null;
    final revision = ++_settingsRevision;
    settingsSaving = true;
    settingsError = validationError;
    if (!_disposed) notifyListeners();
    final stopping = configure(false);
    return _settingsWrite = Future.wait([_settingsWrite, stopping]).then((_) {
      if (_disposed || revision != _settingsRevision) return;
      settingsSaving = false;
      notifyListeners();
    });
  }

  Future<void> flushSettings() {
    _settingsTimer?.cancel();
    _settingsTimer = null;
    final next = _pendingSettings;
    if (next == null) return _settingsWrite;
    _pendingSettings = null;
    final revision = _settingsRevision;
    return _settingsWrite = _settingsWrite.then((_) async {
      if (_disposed || revision != _settingsRevision) return;
      try {
        if (next.port < 1024 || next.port > 65535 || next.token.length < 24) {
          throw ArgumentError(vm.strings.mcpInvalid);
        }
        if (!['document', 'folder', 'custom'].contains(next.scope) ||
            (next.scope == 'custom' &&
                (!p.isAbsolute(next.folder) ||
                    !await Directory(next.folder).exists()))) {
          throw ArgumentError(vm.strings.prefMcpDirectoryError);
        }
        if (_disposed || revision != _settingsRevision) return;
        if (next.token != token) {
          await credentials.writeMcpToken(next.token);
          if (await credentials.readMcpToken() != next.token) {
            throw StateError(
              'System credential storage did not retain the token',
            );
          }
        }
        if (_disposed || revision != _settingsRevision) return;
        final restart = next.port != port || next.token != token;
        port = next.port;
        token = next.token;
        scope = next.scope;
        customFolder = next.folder;
        requireConfirmation = next.confirmation;
        if (restart ||
            next.enabled != enabled ||
            (next.enabled && !server.running)) {
          await configure(next.enabled);
        } else {
          vm.persist();
        }
        if (revision == _settingsRevision) settingsError = '';
      } catch (_) {
        if (revision == _settingsRevision) {
          settingsError = vm.strings.prefMcpSaveFailed;
        }
      } finally {
        if (!_disposed && revision == _settingsRevision) {
          settingsSaving = false;
          notifyListeners();
        }
      }
    });
  }

  bool get available => ![
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.fuchsia,
  ].contains(defaultTargetPlatform);

  String get clientConfiguration => const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'vex': {
        'url': server.endpoint ?? 'http://127.0.0.1:$port/mcp/',
        'headers': {'Authorization': 'Bearer $token'},
      },
    },
  });

  Future<void> testConnection() async {
    if (!available || !server.running) {
      throw StateError(vm.strings.prefMcpNotRunning);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(Uri.parse(server.endpoint!));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': 'vex-connection-test',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-11-25',
            'capabilities': <String, Object?>{},
            'clientInfo': {'name': 'Vex settings', 'version': '1'},
          },
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(body);
      if (data is! Map ||
          data['result'] is! Map ||
          data['result']['serverInfo'] is! Map) {
        throw const FormatException('Invalid MCP initialization response');
      }
      _record('initialize', 'connected');
    } catch (_) {
      _record('initialize', 'connection failed');
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

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
    'find_text',
    'get_map',
    'set_selection',
    'apply_edits',
    'rename_section',
    'add_section',
    'delete_section',
    'move_section',
    'change_section_level',
  };
  Map<String, Object?> get preferences => {
    'enabled': enabled,
    'port': port,
    'scope': scope,
    'customFolder': customFolder,
    'confirm': requireConfirmation,
  };
  Future<void> load(Object? value) async {
    if (value is! Map) return;
    port = (value['port'] as int? ?? 17891).clamp(1024, 65535);
    scope = ['document', 'folder', 'custom'].contains(value['scope'])
        ? value['scope'] as String
        : 'document';
    customFolder = value['customFolder'] as String? ?? '';
    requireConfirmation = value['confirm'] != false;
    if (available) {
      try {
        final savedToken = await credentials.readMcpToken();
        if (_disposed) return;
        if (savedToken != null && savedToken.length >= 24) token = savedToken;
      } catch (_) {
        enabled = false;
        error = vm.strings.prefMcpSaveFailed;
        if (!_disposed) notifyListeners();
        return;
      }
    }
    await configure(value['enabled'] == true, persist: false);
  }

  Future<void> configure(bool value, {bool persist = true}) async {
    if (_disposed) throw StateError('The workspace has closed');
    final configuration = ++_configurationRevision;
    value = value && available;
    enabled = value;
    configuring = true;
    error = '';
    notifyListeners();
    var failure = '';
    try {
      if (value) {
        if (token.length < 24) throw ArgumentError('Invalid access token');
        await credentials.writeMcpToken(token);
        if (_disposed || configuration != _configurationRevision) return;
        if (await credentials.readMcpToken() != token) {
          throw StateError(
            'System credential storage did not retain the token',
          );
        }
        if (_disposed || configuration != _configurationRevision) return;
        await server.start(port: port, token: token);
      } else {
        await server.stop();
      }
    } catch (e) {
      if (_disposed || configuration != _configurationRevision) return;
      failure = vm.strings.prefMcpStartFailed;
      enabled = false;
      await server.stop();
    }
    if (_disposed || configuration != _configurationRevision) return;
    error = failure;
    configuring = false;
    if (persist) vm.persist();
    if (!_disposed) notifyListeners();
  }

  Future<String> _checkPath(String path, _McpAccess access) async {
    if (!p.isAbsolute(path)) {
      throw ArgumentError('An absolute local path is required');
    }
    final resolved = await File(path).resolveSymbolicLinks();
    if (![
      '.md',
      '.markdown',
      '.txt',
    ].contains(p.extension(resolved).toLowerCase())) {
      throw ArgumentError('Only Markdown and text files are accessible');
    }
    final current = access.documentPath;
    if (access.scope == 'document') {
      if (current == null ||
          !p.equals(resolved, await File(current).resolveSymbolicLinks())) {
        throw StateError('The requested file is outside the allowed scope');
      }
      return resolved;
    }
    final directory = access.folder;
    if (directory.isEmpty) throw StateError('No workspace folder is open');
    final root = await Directory(directory).resolveSymbolicLinks();
    if (!p.isWithin(root, resolved)) {
      throw StateError('The requested file is outside the allowed scope');
    }
    return resolved;
  }

  Future<Object?> dispatch(String name, Map<String, Object?> args) async {
    if (_disposed) throw StateError('The workspace has closed');
    final tool = tools.where((tool) => tool['name'] == name).firstOrNull;
    if (tool == null) throw ArgumentError('Unknown tool');
    validateMcpArguments(tool, args);
    final configuration = _configurationRevision;
    final settings = (scope, customFolder, vm.folder?.path);
    final document = vm.current;
    final access = (
      scope: scope,
      documentPath: document.path,
      folder: scope == 'custom'
          ? customFolder
          : vm.folder?.path ??
                (document.path == null ? '' : p.dirname(document.path!)),
    );
    void checkConfiguration() {
      if (_disposed ||
          configuration != _configurationRevision ||
          settings != (scope, customFolder, vm.folder?.path) ||
          !identical(document, vm.current) ||
          document.path != access.documentPath) {
        throw StateError('MCP access settings changed; send a new request');
      }
    }

    final action = name.replaceFirst('vex_', '');
    try {
      if (args['document_id'] != null && args['document_id'] != document.id) {
        throw StateError('Document identity does not match');
      }
      if (args['revision'] != null &&
          args['revision'] != vm.editor.session.revision) {
        throw StateError('Document revision does not match');
      }
      if (scope != 'document' && _documentActions.contains(action)) {
        final path = vm.current.path;
        if (path == null) {
          throw StateError(
            'The current document has no path inside the allowed folder',
          );
        }
        await _checkPath(path, access);
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
        'get_capabilities',
        'read_file',
        'find_text',
        'get_map',
      };
      if (reading.contains(action)) {
        final result = await _read(action, args, access, checkConfiguration);
        checkConfiguration();
        if (action != 'get_operation_audit') _record(name, 'completed');
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
      final revision = vm.editor.session.revision;
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
        if (args['document_id'] != null &&
            args['document_id'] != vm.current.id) {
          throw StateError('Document identity does not match');
        }
        if (vm.editor.source.value.composing.isValid &&
            !vm.editor.source.value.composing.isCollapsed) {
          throw StateError('Finish the current input method composition first');
        }
        final editor = vm.editor;
        String string(String key) {
          final value = args[key];
          if (value is! String) throw ArgumentError('Missing string: $key');
          return value;
        }

        int offset(String key, int fallback) {
          final value = args[key] ?? fallback;
          if (value is! int || !_validOffset(editor.text, value)) {
            throw ArgumentError('Invalid offset: $key');
          }
          return value;
        }

        switch (action) {
          case 'apply_edits':
            final edits = (args['edits']! as List).cast<Map>();
            final patches = edits.map((edit) {
              final start = edit['offset'] as int,
                  length = edit['length'] as int;
              if (!_validOffset(editor.text, start) ||
                  !_validOffset(editor.text, start + length)) {
                throw ArgumentError('Invalid edit range');
              }
              return TextPatch(
                SourceRange(start, start + length),
                edit['text'] as String,
              );
            }).toList()..sort((a, b) => a.range.start.compareTo(b.range.start));
            for (var i = 1; i < patches.length; i++) {
              if (patches[i].range.start < patches[i - 1].range.end ||
                  patches[i].range.start == patches[i - 1].range.start) {
                throw ArgumentError('Edit ranges overlap');
              }
            }
            var text = editor.text;
            for (final patch in patches.reversed) {
              text = patch.apply(text);
            }
            editor.session.replace(text, label: 'MCP 批量修改');
          case 'set_selection':
            final start = offset('start', 0), end = offset('end', 0);
            if (end < start) {
              throw ArgumentError('Selection end precedes start');
            }
            editor.reveal(start, end: end);
          case 'new_document':
            if (scope != 'document') {
              throw StateError(
                'New unnamed documents require current-document access',
              );
            }
            vm.newDocument();
          case 'rename_section':
            editor.session.renameHeading(string('id'), string('title'));
          case 'add_section':
            final title = string('title');
            if (title.trim().isEmpty ||
                title.contains('\n') ||
                title.contains('\r')) {
              throw ArgumentError('Invalid heading title');
            }
            editor.session.addHeading(
              args['id'] as String?,
              child: args['child'] == true,
              title: title,
            );
          case 'delete_section':
            editor.session.deleteHeading(
              string('id'),
              keepContents: args['keep_contents'] == true,
            );
          case 'move_section':
            if (args.containsKey('parent_id') ==
                args.containsKey('direction')) {
              throw ArgumentError(
                'Specify exactly one of direction or parent_id',
              );
            }
            if (args['parent_id'] is String) {
              editor.session.reparentHeading(string('id'), string('parent_id'));
            } else {
              final direction = args['direction'];
              if (direction != -1 && direction != 1) {
                throw ArgumentError('A direction or parent_id is required');
              }
              editor.session.moveHeading(string('id'), direction! as int);
            }
          case 'change_section_level':
            editor.session.changeLevel(string('id'), args['delta']! as int);
          case 'ui_set_theme_mode':
            vm.updateAppearance(mode: ThemeMode.values.byName(string('mode')));
          case 'ui_set_typography':
            vm.updateAppearance(
              typography: MarkdownTypography.values.byName(
                string('typography'),
              ),
            );
          case 'set_map_layout':
            vm.setSummary(
              mode: MindMapLayoutMode.values.byName(string('layout')),
            );
          case 'replace_document':
            editor.session.replace(string('text'), label: 'MCP 替换全文');
          case 'apply_text_edit':
            final start = offset('offset', 0), length = args['length'];
            if (length is! int ||
                length < 0 ||
                !_validOffset(editor.text, start + length)) {
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
            final path = await _checkPath(string('path'), access);
            checkConfiguration();
            await vm.openPath(path, validate: checkConfiguration);
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
        return {
          'ok': true,
          'document_id': vm.current.id,
          'revision': vm.editor.session.revision,
        };
      } finally {
        _mutating = false;
      }
    } catch (_) {
      _record(name, 'declined or failed');
      rethrow;
    }
  }

  static bool _validOffset(String text, int offset) =>
      offset >= 0 &&
      offset <= text.length &&
      !(offset > 0 &&
          offset < text.length &&
          text.codeUnitAt(offset - 1) >= 0xd800 &&
          text.codeUnitAt(offset - 1) <= 0xdbff &&
          text.codeUnitAt(offset) >= 0xdc00 &&
          text.codeUnitAt(offset) <= 0xdfff);

  Future<Object?> _read(
    String action,
    Map<String, Object?> args,
    _McpAccess access,
    void Function() checkConfiguration,
  ) async {
    if (action == 'get_capabilities') {
      return {
        'tools': tools.map((tool) => tool['name']).toList(),
        'scope': scope,
        'write_confirmation': requireConfirmation,
        'offset_unit': 'UTF-16',
        'file_types': ['md', 'markdown', 'txt'],
        'document_id': vm.current.id,
      };
    }
    if (action == 'read_file') {
      final path = await _checkPath(args['path']! as String, access);
      checkConfiguration();
      final opened = await vm.files.read(path);
      return {'path': path, 'name': opened.name, 'text': opened.text};
    }
    if (action == 'find_text') {
      return {
        'matches': [
          for (final range
              in vm.editor
                  .find(
                    args['query']! as String,
                    caseSensitive: args['case_sensitive'] == true,
                  )
                  .take(1000))
            {'offset': range.start, 'length': range.length},
        ],
        'document_id': vm.current.id,
        'revision': vm.editor.session.revision,
      };
    }
    if (action == 'get_map') {
      return {
        'layout': vm.map.mode.name,
        'nodes': [
          for (final h in vm.editor.document.headings)
            {
              'id': h.id,
              'parent_id': h.parentId,
              'title': h.title,
              'level': h.level,
            },
        ],
      };
    }
    if (action == 'list_files') {
      final visible = <Map<String, String?>>[];
      final paths = <String>{};
      if (scope != 'document') {
        final root = access.folder;
        if (root.isNotEmpty) {
          final listed = await vm.files.readFolder(root);
          checkConfiguration();
          for (final path in listed.files) {
            try {
              await _checkPath(path, access);
            } on FileSystemException {
              continue;
            } on StateError {
              continue;
            } on ArgumentError {
              continue;
            }
            checkConfiguration();
            paths.add(p.normalize(path));
            visible.add({'name': p.basename(path), 'path': path});
          }
        }
      }
      for (final doc in vm.documents) {
        if (scope == 'document') {
          if (!identical(doc, vm.current)) continue;
        } else {
          if (doc.path == null) continue;
          try {
            await _checkPath(doc.path!, access);
          } on FileSystemException {
            continue;
          } on StateError {
            continue;
          } on ArgumentError {
            continue;
          }
        }
        if (doc.path == null || paths.add(p.normalize(doc.path!))) {
          visible.add({'name': doc.name, 'path': doc.path});
        }
      }
      final offset = args['offset'] as int? ?? 0,
          limit = args['limit'] as int? ?? 200;
      return visible.skip(offset).take(limit).toList();
    }
    final editor = vm.editor;
    return switch (action) {
      'get_document' => {
        'document_id': vm.current.id,
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
            'parent_id': h.parentId,
            'end': h.section.end,
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
            'List Markdown/text files and open documents in the access scope. Paginated, default 200.',
            {
              'offset': {'type': 'integer', 'minimum': 0},
              'limit': {'type': 'integer', 'minimum': 1, 'maximum': 1000},
            },
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
              'layout': {
                'type': 'string',
                'enum': WorkspaceLayout.values
                    .map((layout) => layout.name)
                    .toList(),
              },
            },
            ['layout'],
          ),
          (
            'ui_set_theme',
            'Select an interface palette.',
            {
              'palette': {'type': 'string', 'enum': paletteNames.keys.toList()},
            },
            ['palette'],
          ),
          (
            'ui_set_language',
            'Select an interface language.',
            {
              'language': {
                'type': 'string',
                'enum': languageNames.keys.toList(),
              },
            },
            ['language'],
          ),
          (
            'ui_show_sidebar_tab',
            'Select files or outline.',
            {
              'tab': {
                'type': 'string',
                'enum': ['files', 'outline'],
              },
            },
            ['tab'],
          ),
          (
            'get_capabilities',
            'Read supported tools and current permission boundaries.',
            {},
            [],
          ),
          (
            'read_file',
            'Read an existing scoped Markdown/text file without changing the active document.',
            {
              'path': {'type': 'string'},
            },
            ['path'],
          ),
          (
            'find_text',
            'Find literal text; offsets use UTF-16 code units.',
            {
              'query': {'type': 'string'},
              'case_sensitive': {'type': 'boolean'},
            },
            ['query'],
          ),
          ('get_map', 'Read the heading-derived map and layout.', {}, []),
          (
            'new_document',
            'Create a new unnamed document without closing existing documents.',
            {},
            [],
          ),
          (
            'set_selection',
            'Select and reveal a source range.',
            {
              'start': {'type': 'integer', 'minimum': 0},
              'end': {'type': 'integer', 'minimum': 0},
            },
            ['start', 'end'],
          ),
          (
            'rename_section',
            'Rename one heading.',
            {
              'id': {'type': 'string'},
              'title': {'type': 'string'},
            },
            ['id', 'title'],
          ),
          (
            'add_section',
            'Add a sibling or child heading; omit id for a top-level heading.',
            {
              'id': {'type': 'string'},
              'title': {'type': 'string'},
              'child': {'type': 'boolean'},
            },
            ['title'],
          ),
          (
            'delete_section',
            'Delete a heading and optionally keep its contents.',
            {
              'id': {'type': 'string'},
              'keep_contents': {'type': 'boolean'},
            },
            ['id'],
          ),
          (
            'move_section',
            'Move a heading among siblings or under a parent.',
            {
              'id': {'type': 'string'},
              'direction': {
                'type': 'integer',
                'enum': [-1, 1],
              },
              'parent_id': {'type': 'string'},
            },
            ['id'],
          ),
          (
            'change_section_level',
            'Promote or demote a heading subtree by one level.',
            {
              'id': {'type': 'string'},
              'delta': {
                'type': 'integer',
                'enum': [-1, 1],
              },
            },
            ['id', 'delta'],
          ),
          (
            'ui_set_theme_mode',
            'Set system, light or dark appearance.',
            {
              'mode': {
                'type': 'string',
                'enum': ThemeMode.values.map((mode) => mode.name).toList(),
              },
            },
            ['mode'],
          ),
          (
            'ui_set_typography',
            'Set document typography independently of the interface palette.',
            {
              'typography': {
                'type': 'string',
                'enum': MarkdownTypography.values
                    .map((type) => type.name)
                    .toList(),
              },
            },
            ['typography'],
          ),
          (
            'set_map_layout',
            'Choose one of the six heading-derived map layouts.',
            {
              'layout': {
                'type': 'string',
                'enum': MindMapLayoutMode.values
                    .map((mode) => mode.name)
                    .toList(),
              },
            },
            ['layout'],
          ),
          (
            'apply_edits',
            'Apply non-overlapping edits atomically against a known document and revision.',
            {
              'edits': {
                'type': 'array',
                'minItems': 1,
                'maxItems': 100,
                'items': {
                  'type': 'object',
                  'properties': {
                    'offset': {'type': 'integer', 'minimum': 0},
                    'length': {'type': 'integer', 'minimum': 0},
                    'text': {'type': 'string'},
                  },
                  'required': ['offset', 'length', 'text'],
                  'additionalProperties': false,
                },
              },
            },
            ['edits', 'revision', 'document_id'],
          ),
        ])
      {
        'name': 'vex_$name',
        'description': description,
        'annotations': {
          'readOnlyHint':
              name.startsWith('get_') ||
              name.startsWith('ui_get_') ||
              ['read_file', 'list_files', 'find_text'].contains(name),
          'openWorldHint': false,
        },
        'inputSchema': {
          'type': 'object',
          'properties': {
            ...properties,
            'revision': {'type': 'integer'},
            'document_id': {'type': 'string'},
          },
          'required': required,
          'additionalProperties': false,
        },
      },
  ];
  @override
  void dispose() {
    _settingsTimer?.cancel();
    _settingsRevision++;
    _disposed = true;
    _configurationRevision++;
    confirm = null;
    server.stop();
    super.dispose();
  }
}
