import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../controller/update_install_controller.dart';
import '../widgets/native_update_dialog.dart';

class UpdateInstallPage extends StatefulWidget {
  const UpdateInstallPage({
    super.key,
    required this.controller,
    this.disposeController = false,
    this.dialog = false,
    this.autoStart = false,
    this.previewControls,
    this.onRefresh,
  });
  final UpdateInstallController controller;
  final bool disposeController, dialog, autoStart;
  final Widget Function(UpdateInstallState)? previewControls;
  final VoidCallback? onRefresh;
  @override
  State<UpdateInstallPage> createState() => _UpdateInstallPageState();
}

class _UpdateInstallPageState extends State<UpdateInstallPage>
    with WidgetsBindingObserver {
  late UpdateInstallState _state;
  late final void Function() _remove;
  bool _closing = false, _canPop = false, _wasAway = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remove = widget.controller.addListener((state) {
      _state = state;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restore();
    });
  }

  Future<void> _restore() async {
    await widget.controller.restore();
    if (!mounted ||
        !widget.autoStart ||
        !widget.controller.mounted ||
        widget.controller.release.apkUrl.isEmpty ||
        _closing) {
      return;
    }
    if (const {
      UpdateInstallPhase.idle,
      UpdateInstallPhase.ready,
      UpdateInstallPhase.permission,
    }.contains(_state.phase)) {
      widget.controller.primary();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _wasAway = true;
    }
    if (state == AppLifecycleState.resumed && _wasAway) {
      _wasAway = false;
      widget.controller.resumed();
    }
  }

  Future<void> _close() async {
    if (_closing || widget.controller.release.forceUpdate) return;
    setState(() => _closing = true);
    final closed = await widget.controller.cancel();
    if (!mounted) return;
    if (!closed) {
      setState(() => _closing = false);
      return;
    }
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remove();
    if (widget.disposeController) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.controller.release;
    final phase = _state.phase;
    final description = switch (phase) {
      UpdateInstallPhase.idle => '准备下载更新',
      UpdateInstallPhase.restoring => '正在恢复更新任务…',
      UpdateInstallPhase.downloading => '正在下载…',
      UpdateInstallPhase.paused => '下载已暂停，等待网络恢复…',
      UpdateInstallPhase.ready => '安装包已准备好',
      UpdateInstallPhase.permission => '等待允许安装此来源的应用',
      UpdateInstallPhase.installing => '已打开系统安装器，请在系统界面完成安装',
      UpdateInstallPhase.failed => '更新未完成',
    };
    final action = switch (phase) {
      UpdateInstallPhase.permission => '去授权安装',
      UpdateInstallPhase.ready => '继续安装',
      UpdateInstallPhase.failed => '重新下载',
      _ => '下载并安装',
    };
    final actionable = const {
      UpdateInstallPhase.idle,
      UpdateInstallPhase.ready,
      UpdateInstallPhase.permission,
      UpdateInstallPhase.failed,
    }.contains(phase);
    final refresh =
        widget.onRefresh != null &&
        release.apkUrl.isEmpty &&
        (phase == UpdateInstallPhase.idle ||
            phase == UpdateInstallPhase.failed);
    if (widget.dialog) {
      return PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: NativeUpdateDialog(
          title: release.forceUpdate ? '发现重要版本更新' : '发现新版本',
          version: release.versionName,
          notes: release.releaseNotes,
          force: release.forceUpdate,
          status: Text(
            description,
            key: const Key('update-install-status'),
            style: const TextStyle(
              fontSize: 13,
              height: 18 / 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
          error: _state.error,
          primary: refresh
              ? '刷新下载信息'
              : switch (phase) {
                  UpdateInstallPhase.downloading || UpdateInstallPhase.paused =>
                    _state.progress == null
                        ? '下载中'
                        : '下载中 ${(_state.progress! * 100).round()}%',
                  UpdateInstallPhase.restoring => '恢复中',
                  UpdateInstallPhase.ready => '安装',
                  UpdateInstallPhase.permission => '授权安装',
                  UpdateInstallPhase.installing => '等待安装',
                  UpdateInstallPhase.failed => '重新下载',
                  UpdateInstallPhase.idle => '立即更新',
                },
          onPrimary: actionable && !_state.busy && !_closing
              ? refresh
                    ? widget.onRefresh
                    : widget.controller.primary
              : null,
          primaryKey: const Key('update-install-primary'),
          later: _closing ? '正在关闭…' : '稍后',
          onLater: _closing ? null : _close,
          laterKey: const Key('update-install-close'),
          extra: widget.previewControls?.call(_state),
        ),
      );
    }
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('安装更新'),
          automaticallyImplyLeading: false,
          leading: release.forceUpdate
              ? null
              : BackButton(onPressed: _closing ? null : _close),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              if (widget.previewControls != null) ...[
                const Text('MOCK · 下载与安装演练', style: ShellTokens.section),
                const Text('仅合成状态，不下载文件、不申请权限、不安装应用。'),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: ShellTokens.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '新版本 ${release.versionName}',
                      style: ShellTokens.cardTitle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      release.releaseNotes.isEmpty
                          ? '体验优化与问题修复'
                          : release.releaseNotes,
                    ),
                    if (release.forceUpdate) const Text('重要更新：请完成更新后继续使用'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                description,
                key: const Key('update-install-status'),
                style: ShellTokens.cardTitle,
              ),
              const SizedBox(height: 12),
              if (_state.busy || _state.progress != null)
                LinearProgressIndicator(value: _state.progress),
              if (_state.progress != null)
                Text('${(_state.progress! * 100).round()}%'),
              if (_state.error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_state.error, key: const Key('update-install-error')),
              ],
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('update-install-primary'),
                onPressed: actionable && !_state.busy && !_closing
                    ? refresh
                          ? widget.onRefresh
                          : widget.controller.primary
                    : null,
                child: Text(
                  _state.busy
                      ? '处理中…'
                      : refresh
                      ? '刷新下载信息'
                      : action,
                ),
              ),
              if (!release.forceUpdate)
                TextButton(
                  key: const Key('update-install-close'),
                  onPressed: _closing ? null : _close,
                  child: Text(_closing ? '正在关闭…' : '稍后更新'),
                ),
              const SizedBox(height: 12),
              const Text(
                '交接系统安装器不代表更新成功。取消安装后可继续安装；退出本页会取消本次更新任务。',
                style: ShellTokens.subtitle,
              ),
              if (widget.previewControls != null)
                widget.previewControls!(_state),
            ],
          ),
        ),
      ),
    );
  }
}
