import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DialerBottomActions extends StatelessWidget {
  const DialerBottomActions({
    super.key,
    required this.busy,
    required this.hasInput,
    required this.translationEnabled,
    required this.dialLabel,
    required this.onClose,
    required this.onDial,
    required this.onDelete,
    required this.onClear,
    this.note,
  });
  final bool busy, hasInput, translationEnabled;
  final String dialLabel;
  final VoidCallback onClose, onDial, onDelete, onClear;
  final Widget? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Action(label: '关闭拨号盘', asset: 'close', size: 52, onTap: onClose),
            _Action(
              label: busy ? '正在打开系统电话' : dialLabel,
              asset: 'call',
              size: 64,
              color: translationEnabled
                  ? const Color(0xFF6C5CE7)
                  : const Color(0xFF34C759),
              onTap: busy ? null : onDial,
            ),
            _Action(
              label: '删除号码，长按清空',
              asset: 'delete',
              size: 52,
              onTap: busy || !hasInput ? null : onDelete,
              onLongPress: busy || !hasInput ? null : onClear,
            ),
          ],
        ),
        if (note != null) ...[const SizedBox(height: 7), note!],
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.asset,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.color,
  });
  final String label, asset;
  final double size;
  final Color? color;
  final VoidCallback? onTap, onLongPress;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    button: true,
    enabled: onTap != null,
    onTap: onTap,
    onLongPress: onLongPress,
    child: ExcludeSemantics(
      child: Tooltip(
        message: label,
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: color == null
                  ? null
                  : [
                      BoxShadow(
                        color: color!.withValues(alpha: .28),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Material(
              color: color ?? Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: Key('dial-$asset'),
                customBorder: const CircleBorder(),
                onTap: onTap,
                onLongPress: onLongPress,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/shell/dial_$asset.svg',
                    width: color != null ? 25 : 28,
                    height: color != null ? 25 : 28,
                    colorFilter: ColorFilter.mode(
                      color != null ? Colors.white : const Color(0xFF4B4D52),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
