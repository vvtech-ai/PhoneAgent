import 'package:flutter/material.dart';
import 'clone_points_button.dart';

class NativeCloneEntry extends StatelessWidget {
  const NativeCloneEntry({
    super.key,
    required this.onTap,
    this.pricePoints,
    this.hasReadyClone = false,
    this.failed = false,
  });
  final bool? hasReadyClone;
  final bool failed;
  final int? pricePoints;
  final VoidCallback? onTap;
  void _open(BuildContext context) {
    if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
      onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final button = ClonePointsButton(
            pricePoints: pricePoints,
            buttonKey: const ValueKey('model-create-clone'),
            minimumWidth: 148,
            onPressed: onTap == null ? null : () => _open(context),
          );
          final action = Semantics(
            container: true,
            button: true,
            enabled: onTap != null,
            label: ClonePointsButton.semanticLabel(pricePoints),
            onTap: onTap == null ? null : () => _open(context),
            excludeSemantics: true,
            child: button,
          );
          final message = Text(
            failed
                ? '声音克隆状态暂不可用，请稍后重试。'
                : hasReadyClone == null
                ? '正在读取声音克隆状态...'
                : hasReadyClone!
                ? '克隆音色已完成，可在支持声音克隆的语音模型中选择使用。'
                : '还没有克隆音色，完成声音克隆后即可使用。',
            style: const TextStyle(
              fontSize: 13,
              height: 19 / 13,
              color: Color(0xFF667085),
            ),
          );
          if (constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [message, const SizedBox(height: 12), action],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    ),
  );
}
