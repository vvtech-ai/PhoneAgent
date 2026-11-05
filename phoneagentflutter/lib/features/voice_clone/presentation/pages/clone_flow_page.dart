import 'dart:async';
import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../../../core/design/native_page_background.dart';
import '../../../../core/design/native_confirmation_dialog.dart';
import '../../domain/clone_enrollment.dart';
import '../controller/clone_flow_controller.dart';
import '../controller/clone_flow_state.dart';
import '../widgets/clone_candidate_step.dart';
import '../widgets/clone_enrollment_steps.dart';
import '../widgets/clone_flow_header.dart';

/// Same page and coordinator for production and isolated synthetic scenarios.
/// The owner disposes the controller (provider in production, preview host in mock).
class CloneFlowPage extends StatefulWidget {
  const CloneFlowPage({
    super.key,
    required this.controller,
    this.preview = false,
    this.onCreationFailed,
  });
  final CloneFlowController controller;
  final bool preview;
  final ValueChanged<String>? onCreationFailed;
  @override
  State<CloneFlowPage> createState() => _CloneFlowPageState();
}

class _CloneFlowPageState extends State<CloneFlowPage>
    with WidgetsBindingObserver {
  late CloneFlowState _state;
  late final void Function() _remove;
  bool _dialog = false, _allowPop = false, _returnScheduled = false;
  bool _retainIdentity = false;
  final _shownCharges = <String>{};
  CloneFlowController get _controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remove = _controller.addListener((value) {
      if (value.chargeNotice.isNotEmpty &&
          _shownCharges.add(value.chargeNoticeId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showNativeNotice(context, value.chargeNotice);
        });
      }
      setState(() {
        _state = value;
        if (value.ui.step == CloneStep.identity) _retainIdentity = true;
        if (value.ui.step == CloneStep.consent) _retainIdentity = false;
      });
      if (value.creationFailed &&
          widget.onCreationFailed != null &&
          !_returnScheduled) {
        _returnScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_controller.restorePreviousCandidate(
            error: value.creationModelError,
          )) {
            _returnScheduled = false;
          } else {
            widget.onCreationFailed?.call(value.creationModelError);
          }
        });
      }
      if (!widget.preview &&
          !_returnScheduled &&
          value.ui.step == CloneStep.confirmed &&
          !_controller.busy &&
          !value.ui.busy) {
        _returnScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _exit();
        });
      }
      if (value.ui.replacement && !value.ui.busy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _state.ui.replacement) _replacement();
        });
      }
    });
    // Saved-recording entry can update the provider synchronously. Start only
    // after the route's first build, and never start a page already disposed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller.stopPreview().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _remove();
    super.dispose();
  }

  Future<bool> _ask(
    String title,
    String message,
    String action, {
    String dismissLabel = '取消',
    bool danger = false,
    bool dismissible = true,
  }) async {
    if (_dialog) return false;
    _dialog = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: const Color(0x8A000000),
      builder: (_) => NativeConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: action,
        dismissLabel: dismissLabel,
        danger: danger,
        allowBack: dismissible,
      ),
    );
    _dialog = false;
    return result == true;
  }

  Future<void> _replacement() async {
    if (_dialog) return;
    final accepted = await _ask(
      '将替换当前认证身份',
      '检测到本次认证人与当前已认证身份不是同一人。继续后，仅在新身份认证成功时更新身份信息，并使原身份创建的克隆音色不可用。',
      '继续并替换',
      danger: true,
    );
    if (!mounted) return;
    if (accepted) {
      await _controller.confirmReplacement();
    } else {
      _controller.cancelReplacement();
    }
  }

  Future<void> _resetIdentity() async {
    if (_dialog || _controller.busy) return;
    final accepted = await _ask(
      '删除身份认证？',
      '删除后，你的身份认证信息及所有克隆音色将被删除，无法恢复。再次使用声音克隆需重新完成身份认证并录制声音。',
      '删除身份及克隆音色',
      danger: true,
    );
    if (mounted && accepted) await _controller.resetIdentity();
  }

  Future<void> _rerecord() async {
    if (!_controller.launch.model.hasPrice) return;
    final accepted = await _ask(
      '确认重新录制？',
      '重新录制会发起一次新的声音克隆，成功生成后将再次扣除 ${_controller.launch.model.pricePoints} 积分。是否继续？',
      '继续重新录制',
    );
    if (mounted && accepted) await _controller.rerecord();
  }

  Future<void> _exit() async {
    if (_dialog || _controller.exitBlocked) return;
    if (_controller.restorePreviousCandidate()) return;
    if (_controller.needsExitConfirmation) {
      final accepted = await _ask(
        '确认返回？',
        '克隆音色已生成，返回后仍可在模型音色中选择，当前模型将恢复系统音色；但本次认证录音不会保存，下次重新克隆时可能需要重新完成人脸识别和声音采集。',
        '确认返回',
        dismissLabel: '继续完成',
        dismissible: false,
      );
      if (!mounted || !accepted) return;
    }
    final allowed = await _controller.prepareExit();
    if (!mounted || !allowed) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = _state.ui;
    final recovery = _state.recovery;
    final candidateResult = _controller.hasCandidateResult;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        body: _ClonePageBackground(
          result:
              candidateResult ||
              ui.step == CloneStep.candidate ||
              ui.step == CloneStep.candidateError,
          child: SafeArea(
            child: Column(
              children: [
                CloneFlowHeader(
                  step: candidateResult ? CloneStep.candidate : ui.step,
                  onBack: _controller.exitBlocked ? null : _exit,
                  onResetIdentity:
                      ui.step == CloneStep.identity &&
                          _state.verifiedName.isNotEmpty &&
                          !_controller.busy &&
                          _controller.services.resetIdentity != null
                      ? _resetIdentity
                      : null,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      candidateResult || ui.step == CloneStep.candidate
                          ? 24
                          : 20,
                      ui.step == CloneStep.consent ? 0 : 12,
                      candidateResult || ui.step == CloneStep.candidate
                          ? 24
                          : 20,
                      24,
                    ),
                    children: [
                      if (widget.preview) ...[
                        const Text(
                          'MOCK · 正式流程装配演练',
                          style: ShellTokens.cardTitle,
                        ),
                        const Text('合成身份与结果；不访问真实账号、摄像头、麦克风或积分。试听仅演练状态，不播放音频。'),
                        const SizedBox(height: 16),
                      ],
                      if (widget.preview) ...[
                        Text(
                          '克隆模型：${_controller.launch.model.name}',
                          style: ShellTokens.cardTitle,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!candidateResult &&
                          ui.error.isNotEmpty &&
                          ui.step != CloneStep.candidate &&
                          ui.step != CloneStep.consent &&
                          ui.step != CloneStep.identity &&
                          ui.step != CloneStep.collecting &&
                          ui.step != CloneStep.checking &&
                          ui.step != CloneStep.generating) ...[
                        Text(ui.error, key: const ValueKey('clone-flow-error')),
                        const SizedBox(height: 16),
                      ],
                      if (!candidateResult &&
                          recovery != CloneFlowRecovery.none)
                        FilledButton(
                          onPressed: ui.busy
                              ? null
                              : recovery == CloneFlowRecovery.restart
                              ? _controller.restartAuthentication
                              : _controller.synchronize,
                          child: Text(
                            recovery == CloneFlowRecovery.restart
                                ? '返回重新认证'
                                : '同步本次状态',
                          ),
                        ),
                      if (_state.resetCleanupPending)
                        TextButton(
                          onPressed: ui.busy ? null : _controller.resetIdentity,
                          child: const Text('重试清理'),
                        ),
                      if (_retainIdentity && ui.step != CloneStep.confirmed)
                        Visibility(
                          key: const Key('clone-retained-identity'),
                          visible: ui.step == CloneStep.identity,
                          maintainState: true,
                          child: CloneIdentityStep(
                            busy: ui.busy || _state.resetCleanupPending,
                            preview: widget.preview,
                            verifiedName: _state.verifiedName,
                            prefilledName: _state.prefilledName,
                            verifiedIdCardMasked: _state.verifiedIdCardMasked,
                            onNumberEdit: _controller.editIdentityNumber,
                            maskIdentity:
                                _state.creationFailed || _state.identityRetry,
                            error: ui.error,
                            onSubmit: _controller.submitIdentity,
                          ),
                        ),
                      if (candidateResult && ui.step != CloneStep.confirmed)
                        CloneCandidateStep(
                          state: ui,
                          ready: _controller.candidateReady,
                          canRerecord:
                              _state.canRerecord &&
                              _controller.launch.model.hasPrice,
                          onSave: _controller.saveRecording,
                          onPreview: _controller.togglePreview,
                          onConfirm: recovery == CloneFlowRecovery.confirmation
                              ? _controller.synchronize
                              : _controller.confirm,
                          onRerecord: _rerecord,
                        ),
                      if ((!candidateResult ||
                              ui.step == CloneStep.confirmed) &&
                          (recovery == CloneFlowRecovery.none ||
                              ui.step == CloneStep.collecting ||
                              ui.step == CloneStep.checking ||
                              ui.step == CloneStep.generating))
                        switch (ui.step) {
                          CloneStep.consent => CloneConsentStep(
                            state: ui,
                            onAgree: _controller.agree,
                            onNext: _controller.next,
                          ),
                          CloneStep.identity => const SizedBox.shrink(),
                          CloneStep.collecting ||
                          CloneStep.checking ||
                          CloneStep.generating => CloneProcessingStep(
                            state: ui,
                          ),
                          CloneStep.candidate => CloneCandidateStep(
                            state: ui,
                            canRerecord: _controller.launch.model.hasPrice,
                            onSave: _controller.saveRecording,
                            onPreview: _controller.togglePreview,
                            onConfirm:
                                recovery == CloneFlowRecovery.confirmation
                                ? _controller.synchronize
                                : _controller.confirm,
                            onRerecord: _rerecord,
                          ),
                          CloneStep.candidateError => Column(
                            children: [
                              if (_state.canRerecord)
                                TextButton(
                                  onPressed:
                                      ui.busy ||
                                          !_controller.launch.model.hasPrice
                                      ? null
                                      : _rerecord,
                                  child: const Text('重新录制'),
                                ),
                              TextButton(
                                onPressed: ui.busy ? null : _exit,
                                child: const Text('返回'),
                              ),
                            ],
                          ),
                          CloneStep.confirmed => Column(
                            children: [
                              Text(
                                widget.preview ? '演练已确认，真实音色未改变' : '已设为默认声音',
                                style: ShellTokens.cardTitle,
                              ),
                              if (ui.busy) const LinearProgressIndicator(),
                              if (_state.saveFailed)
                                OutlinedButton(
                                  onPressed: ui.busy
                                      ? null
                                      : _controller.retrySave,
                                  child: const Text('仅重试保存认证录音'),
                                ),
                              FilledButton(
                                onPressed: ui.busy ? null : _exit,
                                child: const Text('完成并返回'),
                              ),
                            ],
                          ),
                        },
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClonePageBackground extends StatelessWidget {
  const _ClonePageBackground({required this.result, required this.child});
  final bool result;
  final Widget child;
  @override
  Widget build(BuildContext context) => result
      ? ColoredBox(color: const Color(0xFFF8F9FC), child: child)
      : NativePageBackground(child: child);
}
