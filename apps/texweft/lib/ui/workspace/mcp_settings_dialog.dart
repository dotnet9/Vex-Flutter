import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/mcp_server.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';
import 'workspace_mcp.dart';

Future<void> showMcpSettings(BuildContext context, WorkspaceMcp mcp) =>
    showDialog<void>(
      context: context,
      builder: (_) => _McpSettings(mcp: mcp),
    );

class _McpSettings extends StatefulWidget {
  const _McpSettings({required this.mcp});
  final WorkspaceMcp mcp;
  @override
  State<_McpSettings> createState() => _McpSettingsState();
}

class _McpSettingsState extends State<_McpSettings> {
  late final _port = TextEditingController(text: '${widget.mcp.port}');
  late final _token = TextEditingController(text: widget.mcp.token);
  late final _folder = TextEditingController(text: widget.mcp.customFolder);
  late bool _enabled = widget.mcp.enabled,
      _confirmation = widget.mcp.requireConfirmation;
  late String _scope = widget.mcp.scope;
  String _error = '';
  bool _busy = false;
  @override
  void dispose() {
    _port.dispose();
    _token.dispose();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text);
    if (port == null ||
        port < 1024 ||
        port > 65535 ||
        _token.text.trim().length < 24) {
      setState(() => _error = context.l10n.mcpInvalid);
      return;
    }
    setState(() => _busy = true);
    final mcp = widget.mcp;
    mcp.port = port;
    mcp.token = _token.text.trim();
    mcp.scope = _scope;
    mcp.customFolder = _folder.text.trim();
    mcp.requireConfirmation = _confirmation;
    await mcp.configure(_enabled);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = mcp.error;
    });
    if (_error.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, colors = Theme.of(context).colorScheme;
    return AppDialog(
      title: l.mcpSettings,
      width: 620,
      actions: [
        AppButton(
          label: l.cancel,
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        AppButton(
          label: l.save,
          primary: true,
          onPressed: _busy ? null : _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mcpIntro, style: const TextStyle(fontSize: 14, height: 1.8)),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.mcpEnable),
            value: _enabled,
            onChanged: _busy ? null : (v) => setState(() => _enabled = v),
          ),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '127.0.0.1',
                  readOnly: true,
                  decoration: InputDecoration(labelText: l.mcpAddress),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l.mcpPort),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _token,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(labelText: l.mcpToken),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              AppButton(
                label: l.mcpGenerate,
                bordered: true,
                onPressed: () => _token.text = McpServer.generateToken(),
              ),
              AppButton(
                label: l.copy,
                icon: 'copy',
                bordered: true,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _token.text)),
              ),
              AppButton(
                label: l.mcpCopyAddress,
                bordered: true,
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: 'http://127.0.0.1:${_port.text}/mcp/'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          DropdownButtonFormField<String>(
            initialValue: _scope,
            decoration: InputDecoration(labelText: l.mcpScope),
            isExpanded: true,
            items: [
              for (final entry in [
                ('document', l.mcpDocument),
                ('folder', l.mcpFolder),
                ('custom', l.mcpCustom),
              ])
                DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
            ],
            onChanged: (v) => setState(() => _scope = v!),
          ),
          if (_scope == 'custom') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _folder,
              decoration: InputDecoration(labelText: l.mcpCustom),
            ),
          ],
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l.mcpConfirm, style: const TextStyle(fontSize: 14)),
            value: _confirmation,
            onChanged: (v) => setState(() => _confirmation = v!),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: widget.mcp,
            builder: (context, _) => Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: widget.mcp.server.running
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.mcp.server.running
                        ? '${l.mcpRunning} · ${widget.mcp.server.endpoint}'
                        : l.mcpStopped,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error,
                style: TextStyle(color: colors.error, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
