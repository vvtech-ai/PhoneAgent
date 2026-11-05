import 'package:flutter/material.dart';
import '../../domain/startup_update.dart';
import 'native_update_dialog.dart';

/// Owns only the external-link handoff and its foreground return lifecycle.
class IosUpdateDialog extends StatefulWidget {
  const IosUpdateDialog({
    super.key,
    required this.offer,
    required this.open,
    required this.onLater,
    required this.onRefresh,
  });
  final StartupUpdateOffer offer;
  final Future<void> Function(String) open;
  final VoidCallback onLater;
  final Future<void> Function() onRefresh;

  @override
  State<IosUpdateDialog> createState() => _IosUpdateDialogState();
}

class _IosUpdateDialogState extends State<IosUpdateDialog>
    with WidgetsBindingObserver {
  bool _busy = false, _awaitingReturn = false, _leftApp = false;
  bool _returnPending = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awaitingReturn) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _leftApp = true;
    } else if (state == AppLifecycleState.resumed && _leftApp) {
      _returnPending = true;
      if (!_busy) _refreshOnReturn();
    }
  }

  Future<void> _refreshOnReturn() async {
    if (!mounted || !_returnPending) return;
    _awaitingReturn = false;
    _returnPending = false;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    _awaitingReturn = widget.offer.release.forceUpdate;
    _leftApp = false;
    _returnPending = false;
    try {
      await widget.open(widget.offer.release.iosSourceUrl);
      if (!mounted) return;
      if (!widget.offer.release.forceUpdate) widget.onLater();
    } catch (_) {
      if (!mounted) return;
      _awaitingReturn = false;
      _returnPending = false;
      setState(() => _error = '无法打开更新链接，请重试');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_returnPending) _refreshOnReturn();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.offer.release;
    return PopScope(
      canPop: !release.forceUpdate && !_busy,
      child: NativeUpdateDialog(
        title: release.forceUpdate ? '发现重要版本更新' : '发现新版本',
        version: release.versionName,
        notes: release.releaseNotes,
        force: release.forceUpdate,
        primary: _busy ? '处理中' : '立即更新',
        onPrimary: _busy ? null : _open,
        primaryKey: const Key('startup-update-install'),
        onLater: _busy ? null : widget.onLater,
        laterKey: const Key('startup-update-later'),
        error: _error,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
