import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/update_download_service.dart';
import '../../data/services/update_install_service.dart';
import '../../data/services/update_service.dart';
import '../../l10n/l10n.dart';
import '../core/app_widgets.dart';

Future<void> showUpdateDownload(
  BuildContext context, {
  required String tag,
  required UpdatePackage package,
  UpdateDownloader? downloader,
  UpdateInstaller? installer,
  UpdateClose? closeWorkspace,
}) => showDialog<void>(
  context: context,
  builder: (_) => _UpdateDialog(
    tag: tag,
    package: package,
    downloader: downloader ?? UpdateDownloader(),
    installer: installer ?? SystemUpdateInstaller(),
    closeWorkspace: closeWorkspace,
  ),
);

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.tag,
    required this.package,
    required this.downloader,
    required this.installer,
    this.closeWorkspace,
  });
  final String tag;
  final UpdatePackage package;
  final UpdateDownloader downloader;
  final UpdateInstaller installer;
  final UpdateClose? closeWorkspace;
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  UpdateCancellation? _cancellation;
  VerifiedUpdate? _verified;
  UpdateProgress? _progress;
  bool _downloading = false, _installing = false, _handedOff = false;
  final _progressClock = Stopwatch();
  String? _error;

  Future<void> _download() async {
    if (_downloading || _installing) return;
    final cancellation = UpdateCancellation();
    setState(() {
      _cancellation = cancellation;
      _downloading = true;
      _error = null;
      _progress = null;
      _progressClock.reset();
      _progressClock.start();
    });
    try {
      final result = await widget.downloader.download(
        widget.package,
        cancellation: cancellation,
        onProgress: (progress) {
          if (mounted &&
              (_progress == null ||
                  progress.fraction == 1 ||
                  _progressClock.elapsedMilliseconds >= 80)) {
            setState(() => _progress = progress);
            _progressClock.reset();
          }
        },
      );
      if (!mounted) {
        await result.discard();
        return;
      }
      setState(() => _verified = result);
    } on UpdateCancelled {
      // Closing the dialog and explicit cancellation both leave the document alone.
    } on UpdateIntegrityException {
      if (mounted) setState(() => _error = context.l10n.updateIntegrityError);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.updateDownloadError);
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _cancellation = null;
        });
      }
    }
  }

  Future<void> _install() async {
    if (_installing || _verified == null) return;
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      final launched = await widget.installer.install(
        _verified!,
        closeWorkspace: widget.closeWorkspace,
      );
      if (launched) {
        _handedOff = true;
        if (mounted) Navigator.pop(context);
      }
    } on UpdateInstallPermissionRequired {
      if (mounted) {
        setState(() => _error = context.l10n.updateInstallPermission);
      }
    } on UpdateIntegrityException {
      await _verified?.discard();
      _verified = null;
      if (mounted) setState(() => _error = context.l10n.updateIntegrityError);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.updateInstallError);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    // External installers may still need the file after Vex exits.
    if (!_handedOff && !_installing && _verified != null) {
      unawaited(_verified!.discard().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope<void>(
      canPop: !_installing,
      child: AppDialog(
        title: l.updateAvailable(widget.tag),
        width: 420,
        canClose: !_installing,
        actions: [
          if (!_installing)
            AppButton(label: l.cancel, onPressed: () => Navigator.pop(context)),
          if (_installing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  l.updateOpeningInstaller,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          if (!_downloading && !_installing)
            AppButton(
              key: const ValueKey('update-primary'),
              primary: true,
              label: _verified != null
                  ? l.updateInstall
                  : _error != null
                  ? l.updateRetry
                  : l.updateDownload,
              onPressed: _verified != null ? _install : _download,
            ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _installing
                  ? l.updateOpeningInstaller
                  : _verified != null
                  ? l.updateVerified
                  : l.updateDownloadPrompt,
              style: const TextStyle(fontSize: 15, height: 1.65),
            ),
            const SizedBox(height: 12),
            Text(
              widget.package.installer.size < 1024 * 1024
                  ? '${(widget.package.installer.size / 1024).ceil()} KB'
                  : '${(widget.package.installer.size / 1024 / 1024).toStringAsFixed(1)} MB',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_downloading) ...[
              const SizedBox(height: 18),
              if (_progress == null)
                const LinearProgressIndicator()
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final value = _progress!.fraction;
                    final style = DefaultTextStyle.of(context).style
                        .copyWith(fontSize: 14);
                    final label = TextPainter(
                      text: TextSpan(text: '100%', style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final labelWidth = (label.width + 12).clamp(
                      44.0,
                      constraints.maxWidth,
                    );
                    final height = (label.height + 16).clamp(
                      44.0,
                      double.infinity,
                    );
                    label.dispose();
                    return Semantics(
                      value: '${(value * 100).round()}%',
                      child: SizedBox(
                        key: const ValueKey('update-progress'),
                        height: height,
                        child: Stack(
                          children: [
                            Positioned(
                              left:
                                  (constraints.maxWidth * value -
                                          labelWidth / 2)
                                      .clamp(
                                        0,
                                        constraints.maxWidth - labelWidth,
                                      ),
                              top: 0,
                              width: labelWidth,
                              child: Text(
                                '${(value * 100).floor()}%',
                                textAlign: TextAlign.center,
                                style: style,
                                maxLines: 1,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(
                _error!,
                key: const ValueKey('update-error'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
