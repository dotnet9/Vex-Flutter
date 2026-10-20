import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/services/mcp_server.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'preference_controls.dart';
import 'workspace_mcp.dart';

/// The host owns the only scroll view and the fixed dialog chrome.
class McpSettingsPane extends StatefulWidget {
  const McpSettingsPane({super.key, required this.mcp, this.initialTab = 0});
  final WorkspaceMcp mcp;
  final int initialTab;
  @override
  State<McpSettingsPane> createState() => _McpSettingsPaneState();
}

class _McpSettingsPaneState extends State<McpSettingsPane> {
  late String _port = '${widget.mcp.port}',
      _token = widget.mcp.token,
      _folder = widget.mcp.customFolder,
      _scope = widget.mcp.scope;
  late bool _enabled = widget.mcp.enabled,
      _confirmation = widget.mcp.requireConfirmation;
  late int _tab = widget.initialTab;
  bool _busy = false, _reveal = false;
  String _error = '', _result = '';

  @override
  void initState() {
    super.initState();
    widget.mcp.addListener(_syncEnabled);
  }

  void _syncEnabled() {
    if (mounted && !widget.mcp.settingsSaving) {
      setState(() => _enabled = widget.mcp.enabled);
    }
  }

  @override
  void dispose() {
    widget.mcp.removeListener(_syncEnabled);
    unawaited(widget.mcp.flushSettings());
    super.dispose();
  }

  String _validationError() {
    final port = int.tryParse(_port);
    if (port == null ||
        port < 1024 ||
        port > 65535 ||
        _token.trim().length < 24) {
      return context.l10n.mcpInvalid;
    }
    if (_scope == 'custom' &&
        (!p.isAbsolute(_folder.trim()) ||
            !Directory(_folder.trim()).existsSync())) {
      return context.l10n.prefMcpDirectoryError;
    }
    return '';
  }

  void _save({bool immediate = false, bool stopping = false}) {
    final validation = _validationError();
    setState(() => _error = '');
    final mcp = widget.mcp;
    if (stopping && validation.isNotEmpty) {
      unawaited(mcp.stopFromSettings(validationError: validation));
      return;
    }
    if (validation.isNotEmpty) {
      mcp.rejectPreferences(validation);
      return;
    }
    mcp.updatePreferences((
      enabled: _enabled,
      port: int.parse(_port),
      token: _token.trim(),
      scope: _scope,
      folder: _folder.trim(),
      confirmation: _confirmation,
    ), immediate: immediate);
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _result = '';
      _error = '';
    });
    try {
      await widget.mcp.testConnection();
      if (mounted) setState(() => _result = context.l10n.prefMcpConnected);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = Theme.of(context).colorScheme;
    if (!widget.mcp.available) {
      return Text(
        l.prefMcpMobile,
        style: const TextStyle(fontSize: 14, height: 1.8),
      );
    }
    return ListenableBuilder(
      listenable: widget.mcp,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.outlineVariant)),
            ),
            child: Row(
              children: [
                for (final (index, label) in [
                  (0, l.prefMcpServer),
                  (1, l.prefMcpClients),
                  (2, l.prefMcpAudit),
                ])
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 20),
                      child: Semantics(
                        selected: _tab == index,
                        child: InkWell(
                          key: ValueKey('mcp-tab-$index'),
                          onTap: _busy
                              ? null
                              : () => setState(() {
                                  _tab = index;
                                  _error = '';
                                  _result = '';
                                }),
                          child: Container(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 2,
                                  color: _tab == index
                                      ? c.primary
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: _tab == index
                                    ? c.primary
                                    : c.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_tab == 0) ...[
            PreferenceSwitch(
              label: l.mcpEnable,
              note: '127.0.0.1',
              value: _enabled,
              key: const ValueKey('mcp-enabled'),
              onChanged: (v) {
                setState(() => _enabled = v);
                _save(immediate: true, stopping: !v);
              },
            ),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.mcp.error.isNotEmpty
                          ? c.error
                          : widget.mcp.server.running
                          ? c.primary
                          : c.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.mcp.configuring
                          ? (widget.mcp.enabled
                                ? l.prefMcpStarting
                                : l.prefMcpStopping)
                          : widget.mcp.error.isNotEmpty
                          ? widget.mcp.error
                          : widget.mcp.server.running
                          ? '${l.mcpRunning} · ${widget.mcp.server.endpoint}'
                          : l.mcpStopped,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PreferenceText(
              label: l.mcpPort,
              value: _port,
              numeric: true,
              key: const ValueKey('mcp-port'),
              onChanged: (v) {
                _port = v;
                _save();
              },
            ),
            PreferenceText(
              key: const ValueKey('mcp-token'),
              label: l.mcpToken,
              value: _token,
              obscure: !_reveal,
              onChanged: (v) {
                _token = v;
                _save();
              },
              suffix: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    icon: 'eye',
                    tooltip: l.prefMcpReveal,
                    height: 28,
                    padding: 5,
                    onPressed: () => setState(() => _reveal = !_reveal),
                  ),
                  AppButton(
                    icon: 'refresh',
                    tooltip: l.mcpGenerate,
                    height: 28,
                    padding: 5,
                    onPressed: () {
                      setState(() => _token = McpServer.generateToken());
                      _save(immediate: true);
                    },
                  ),
                ],
              ),
            ),
            PreferenceDropdown(
              label: l.mcpScope,
              value: _scope,
              items: [
                ('document', l.mcpDocument),
                ('folder', l.mcpFolder),
                ('custom', l.mcpCustom),
              ],
              onChanged: (value) {
                setState(() => _scope = value);
                _save(immediate: true);
              },
            ),
            if (_scope == 'custom')
              PreferenceText(
                label: l.mcpCustom,
                value: _folder,
                key: const ValueKey('mcp-folder'),
                onChanged: (v) {
                  _folder = v;
                  _save();
                },
              ),
            PreferenceSwitch(
              label: l.mcpConfirm,
              value: _confirmation,
              onChanged: (v) {
                setState(() => _confirmation = v);
                _save(immediate: true);
              },
            ),
          ],
          if (_tab == 1) ...[
            const PreferenceSection('HTTP'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: c.outlineVariant),
              ),
              child: SelectableText(
                widget.mcp.clientConfiguration,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  fontFamily: 'CascadiaCode',
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: l.prefMcpCopyConfig,
                  icon: 'copy',
                  bordered: true,
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: widget.mcp.clientConfiguration),
                  ),
                ),
                AppButton(
                  label: l.prefMcpTest,
                  primary: true,
                  onPressed: _busy ? null : _test,
                ),
              ],
            ),
          ],
          if (_tab == 2)
            if (widget.mcp.audit.isEmpty)
              Text(l.mcpAuditEmpty, style: const TextStyle(fontSize: 14))
            else
              Table(
                columnWidths: const {
                  0: FixedColumnWidth(66),
                  1: FlexColumnWidth(1.3),
                  2: FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(
                  horizontalInside: BorderSide(color: c.outlineVariant),
                ),
                children: [
                  TableRow(
                    children: [
                      for (final text in [
                        l.prefMcpTime,
                        l.prefMcpAction,
                        l.prefMcpResult,
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final item in widget.mcp.audit)
                    TableRow(
                      children: [
                        for (final text in [
                          DateTime.tryParse(item['time'] ?? '')
                                  ?.toLocal()
                                  .toIso8601String()
                                  .substring(11, 19) ??
                              '',
                          item['tool'] ?? '',
                          item['result'] ?? '',
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 2,
                            ),
                            child: Text(
                              text,
                              style: const TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: LinearProgressIndicator(),
            ),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _result,
                style: TextStyle(color: c.primary, fontSize: 13),
              ),
            ),
          if (widget.mcp.settingsError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.mcp.settingsError,
                style: TextStyle(color: c.error, fontSize: 13),
              ),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                _error,
                style: TextStyle(color: c.error, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
