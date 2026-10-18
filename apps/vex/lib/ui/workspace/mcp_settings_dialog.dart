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

  Future<void> _apply() async {
    final port = int.tryParse(_port);
    if (port == null ||
        port < 1024 ||
        port > 65535 ||
        _token.trim().length < 24) {
      setState(() => _error = context.l10n.mcpInvalid);
      return;
    }
    if (_scope == 'custom' &&
        (!p.isAbsolute(_folder.trim()) ||
            !await Directory(_folder.trim()).exists())) {
      if (mounted) setState(() => _error = context.l10n.prefMcpDirectoryError);
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final mcp = widget.mcp;
    mcp.port = port;
    mcp.token = _token.trim();
    mcp.scope = _scope;
    mcp.customFolder = _folder.trim();
    mcp.requireConfirmation = _confirmation;
    await mcp.configure(_enabled);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = mcp.error;
      });
    }
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
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.mcp.server.running
                      ? c.primary
                      : c.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.mcp.server.running
                      ? '${l.mcpRunning} · ${widget.mcp.server.endpoint}'
                      : l.mcpStopped,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_tab == 0) ...[
            PreferenceSwitch(
              label: l.mcpEnable,
              note: '127.0.0.1',
              value: _enabled,
              onChanged: _busy ? null : (v) => setState(() => _enabled = v),
            ),
            PreferenceText(
              label: l.mcpPort,
              value: _port,
              numeric: true,
              onChanged: (v) => _port = v,
            ),
            PreferenceText(
              key: const ValueKey('mcp-token'),
              label: l.mcpToken,
              value: _token,
              obscure: !_reveal,
              onChanged: (v) => _token = v,
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
                    onPressed: () =>
                        setState(() => _token = McpServer.generateToken()),
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
              onChanged: (value) => setState(() => _scope = value),
            ),
            if (_scope == 'custom')
              PreferenceText(
                label: l.mcpCustom,
                value: _folder,
                onChanged: (v) => _folder = v,
              ),
            PreferenceSwitch(
              label: l.mcpConfirm,
              value: _confirmation,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _confirmation = v),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  label: l.prefApply,
                  primary: true,
                  onPressed: _busy ? null : _apply,
                ),
                AppButton(
                  label: l.prefMcpStop,
                  bordered: true,
                  onPressed: _busy || !widget.mcp.server.running
                      ? null
                      : () async {
                          await widget.mcp.configure(false);
                          if (mounted) setState(() => _enabled = false);
                        },
                ),
              ],
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
