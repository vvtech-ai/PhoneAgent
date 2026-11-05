import '../../../../core/design/native_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../domain/clone_enrollment.dart';
import '../../domain/clone_creation.dart';
import '../controller/clone_enrollment_controller.dart';
import '../widgets/clone_enrollment_steps.dart';
import '../widgets/clone_candidate_step.dart';

/// Shared form/result widgets; current entry deliberately permits preview only.
class CloneEnrollmentPreviewPage extends StatefulWidget {
  const CloneEnrollmentPreviewPage({
    super.key,
    required this.port,
    this.start = CloneCreationStart.authentication,
    this.reuseOnRerecord = false,
    this.modelName,
  });
  final CloneEnrollmentPort port;
  final CloneCreationStart start;
  final bool reuseOnRerecord;
  final String? modelName;
  @override
  State<CloneEnrollmentPreviewPage> createState() =>
      _CloneEnrollmentPreviewPageState();
}

class _CloneEnrollmentPreviewPageState
    extends State<CloneEnrollmentPreviewPage> {
  late final _controller = CloneEnrollmentController(
    widget.port,
    reuseOnRerecord: widget.reuseOnRerecord,
  );
  late final void Function() _remove;
  CloneEnrollmentState _state = const CloneEnrollmentState();
  bool _dialogOpen = false, _allowPop = false;
  int _formRevision = 0;
  @override
  void initState() {
    super.initState();
    _remove = _controller.addListener((value) {
      setState(() {
        if (_state.busy &&
            value.step == CloneStep.identity &&
            value.error.isNotEmpty) {
          _formRevision++;
        }
        _state = value;
      });
      if (value.replacement) _replacement();
    }, fireImmediately: false);
    if (widget.start != CloneCreationStart.authentication) {
      _controller.openCandidate(widget.start);
    }
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirm(
    String title,
    String message,
    String action, {
    String cancel = '取消',
  }) async {
    if (_dialogOpen) return false;
    _dialogOpen = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => NativeConfirmationDialog(
        title: title,
        message: message,
        dismissLabel: cancel,
        confirmLabel: action,
      ),
    );
    _dialogOpen = false;
    return result == true;
  }

  Future<void> _replacement() async {
    final accepted = await _confirm(
      '将替换当前认证身份',
      '仅在新身份认证成功时更新身份信息，并使原身份创建的克隆音色不可用。此处仅演练，不替换真实身份。',
      '继续并替换',
    );
    if (!mounted) return;
    if (accepted) {
      await _controller.confirmReplacement();
    } else {
      _controller.cancelReplacement();
    }
  }

  Future<void> _rerecord() async {
    final accepted = await _confirm(
      '确认重新录制？',
      '重新录制会发起一次新的声音克隆，成功生成后将再次扣除 300 积分。此处仅演练，不扣除真实积分。',
      '继续重新录制',
    );
    if (mounted && accepted) _controller.rerecord();
  }

  Future<void> _exit() async {
    if (_dialogOpen || _controller.exitBlocked) return;
    if (_controller.needsExitConfirmation) {
      final accepted = await _confirm(
        '确认返回？',
        '克隆音色已生成，返回后仍可在模型音色中选择，当前模型将恢复系统音色；但本次认证录音不会保存，下次重新克隆时可能需要重新完成人脸识别和声音采集。\nMOCK：不修改真实模型或录音。',
        '确认返回',
        cancel: '继续完成',
      );
      if (!mounted || !accepted) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        _allowPop ||
        (!_controller.exitBlocked && !_controller.needsExitConfirmation),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          !_state.showSaveRecording ||
                  _state.step == CloneStep.candidate ||
                  _state.step == CloneStep.confirmed
              ? '我的声音克隆'
              : '身份认证',
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: _state.busy ? null : _exit,
          icon: const BackButtonIcon(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('MOCK · 克隆交互演练', style: ShellTokens.cardTitle),
            const Text(
              '不提交身份、不启用摄像头或麦克风、不播放真实音频、不扣积分；所有结果均为合成。',
              style: ShellTokens.subtitle,
            ),
            const SizedBox(height: 20),
            if (widget.modelName != null)
              Text('克隆模型：${widget.modelName}', style: ShellTokens.cardTitle),
            if (_state.error.isNotEmpty &&
                _state.step != CloneStep.consent &&
                _state.step != CloneStep.identity &&
                _state.step != CloneStep.collecting &&
                _state.step != CloneStep.checking &&
                _state.step != CloneStep.generating)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _state.error,
                  key: const ValueKey('clone-flow-error'),
                ),
              ),
            switch (_state.step) {
              CloneStep.consent => CloneConsentStep(
                state: _state,
                onAgree: _controller.agree,
                onNext: _controller.next,
              ),
              CloneStep.identity => CloneIdentityStep(
                key: ValueKey(_formRevision),
                busy: _state.busy,
                preview: true,
                error: _state.error,
                onSubmit: _controller.submitIdentity,
              ),
              CloneStep.collecting ||
              CloneStep.checking ||
              CloneStep.generating => CloneProcessingStep(state: _state),
              CloneStep.candidateError => Column(
                children: [
                  OutlinedButton(
                    onPressed: _controller.retryCandidate,
                    child: Text(
                      widget.start == CloneCreationStart.existingCandidate
                          ? '重新读取候选状态'
                          : '重试生成（MOCK）',
                    ),
                  ),
                  TextButton(onPressed: _rerecord, child: const Text('重新录制')),
                ],
              ),
              CloneStep.candidate => CloneCandidateStep(
                state: _state,
                onSave: _controller.saveRecording,
                onPreview: _controller.togglePreview,
                onConfirm: _controller.confirm,
                onRerecord: _rerecord,
              ),
              CloneStep.confirmed => Column(
                children: [
                  const Text('演练已确认，真实音色未改变', style: ShellTokens.cardTitle),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _exit, child: const Text('完成并返回')),
                ],
              ),
            },
          ],
        ),
      ),
    ),
  );
}
