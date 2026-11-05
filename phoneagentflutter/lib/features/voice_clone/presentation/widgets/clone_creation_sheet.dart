import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'clone_reauthentication_dialog.dart';
import 'clone_entitlement_dialog.dart';
import '../../domain/clone_creation.dart';
import '../controller/clone_creation_controller.dart';

Future<CloneCreationLaunch?> showCloneCreationSheet(
  BuildContext context,
  CloneCreationPort port, {
  String initialError = '',
  String? targetModelId,
  Future<void> Function()? onUpgrade,
  bool Function()? isCurrent,
}) => showModalBottomSheet<CloneCreationLaunch>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  barrierColor: const Color(0x73000000),
  constraints: const BoxConstraints(maxWidth: 420),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => CloneCreationSheet(
    port: port,
    initialError: initialError,
    targetModelId: targetModelId,
    onUpgrade: onUpgrade,
    isCurrent: isCurrent,
  ),
);

class CloneCreationSheet extends StatefulWidget {
  const CloneCreationSheet({
    super.key,
    required this.port,
    this.initialError = '',
    this.targetModelId,
    this.onUpgrade,
    this.isCurrent,
  });
  final String initialError;
  final String? targetModelId;
  final CloneCreationPort port;
  final Future<void> Function()? onUpgrade;
  final bool Function()? isCurrent;
  @override
  State<CloneCreationSheet> createState() => _CloneCreationSheetState();
}

class _CloneCreationSheetState extends State<CloneCreationSheet> {
  late final _controller = CloneCreationController(widget.port);
  late final void Function() _remove;
  CloneCreationState _state = const CloneCreationState();
  bool _dialog = false;
  @override
  void initState() {
    super.initState();
    _remove = _controller.addListener((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state.launch != null) {
        Navigator.pop(context, state.launch);
      } else if (state.entitlementDenied && !_dialog) {
        _entitlement();
      } else if (state.confirmReauthentication && !_dialog) {
        _confirm();
      }
    }, fireImmediately: false);
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    await _controller.load();
    if (!mounted ||
        widget.isCurrent?.call() == false ||
        widget.initialError.isNotEmpty ||
        _state.error.isNotEmpty ||
        _state.entitlementDenied ||
        _state.entitlementUnknown) {
      return;
    }
    final target = widget.targetModelId;
    if (target != null) await _controller.select(target);
  }

  Future<void> _entitlement() async {
    _dialog = true;
    final upgrade = await showDialog<bool>(
      context: context,
      builder: (_) => const CloneEntitlementDialog(),
    );
    if (!mounted) return;
    if (widget.isCurrent?.call() == false) {
      _dialog = false;
      _close();
      return;
    }
    _controller.dismissEntitlement();
    if (upgrade == true && widget.onUpgrade != null) {
      await widget.onUpgrade!();
      if (!mounted) return;
      _dialog = false;
      if (widget.isCurrent?.call() == false) {
        _close();
        return;
      }
      await _controller.load();
    } else {
      _dialog = false;
      _close();
    }
  }

  Future<void> _confirm() async {
    _dialog = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8A000000),
      builder: (_) =>
          CloneReauthenticationDialog(modelName: _state.selected!.name),
    );
    _dialog = false;
    if (!mounted) return;
    if (accepted == true) {
      await _controller.confirmReauthentication();
    } else {
      _controller.cancelReauthentication();
    }
  }

  void _close() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _state.entitlementDenied ? const SizedBox.shrink() : _picker(context);

  Widget _picker(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '选择声音克隆模型',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: Semantics(
                  container: true,
                  button: true,
                  label: '关闭克隆模型选择',
                  onTap: _close,
                  excludeSemantics: true,
                  child: IconButton(
                    tooltip: '关闭',
                    onPressed: _close,
                    icon: const Text(
                      '×',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontSize: 22, color: Color(0xFF8B8FA3)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Text(
            '仅展示支持声音克隆的语音大模型',
            style: TextStyle(fontSize: 13, color: Color(0xFF8B8FA3)),
          ),
          const SizedBox(height: 14),
          if (_state.loading)
            const SizedBox(
              height: 120,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (widget.initialError.isNotEmpty && _state.error.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                widget.initialError,
                key: const Key('clone-creation-error'),
                style: const TextStyle(color: Color(0xFFE14D46), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          for (final model
              in _state.entitlementUnknown
                  ? const <CloneCreationModel>[]
                  : _state.models.where(
                      (model) =>
                          widget.targetModelId == null ||
                          model.id == widget.targetModelId,
                    ))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OutlinedButton(
                key: ValueKey('clone-create-${model.id}'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: model.available
                      ? Colors.white
                      : const Color(0xFFF7F7F8),
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: !_state.busy
                    ? () => _controller.select(model.id)
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            !model.available
                                ? model.unavailableReason
                                : model.requiresReauthentication
                                ? '已有克隆音色'
                                : model.hasCandidate
                                ? '候选音色待确认'
                                : '尚未克隆音色',
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              color:
                                  model.available &&
                                      model.requiresReauthentication
                                  ? const Color(0xFF0A84FF)
                                  : const Color(0xFF8B8FA3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_state.busy && _state.selected?.id == model.id)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Row(
                        children: [
                          if (model.available)
                            Semantics(
                              label: model.hasPrice
                                  ? '${model.pricePoints}积分'
                                  : '价格暂不可用',
                              child: ExcludeSemantics(
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/images/shell/points.svg',
                                      width: 15,
                                      height: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      model.hasPrice
                                          ? '${model.pricePoints}'
                                          : '--',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Text(
                            '  ›',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xFF98A2B3),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (_state.error.isNotEmpty)
            Text(
              _state.error,
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                color: Color(0xFFE14D46),
              ),
            ),
          if (_state.error.isNotEmpty)
            TextButton(
              onPressed: _state.busy || _state.loading
                  ? null
                  : _controller.load,
              child: const Text('重试'),
            ),
        ],
      ),
    ),
  );
}
