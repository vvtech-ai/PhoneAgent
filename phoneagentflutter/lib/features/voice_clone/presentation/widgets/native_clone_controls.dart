import 'package:flutter/material.dart';
import '../../../../core/design/native_action_style.dart';

const cloneInk = Color(0xFF111827);
const cloneSecondary = Color(0xFF6B7280);

// Compose's 0.5sp tracking scales with the font; Flutter tracking does not.
double cloneTextSpacing(BuildContext context, double fontSize) =>
    .5 * MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;

BoxDecoration cloneCard({
  Color color = Colors.white,
  Color border = const Color(0xFFF0F2F6),
  double radius = 24,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border),
);

class CloneCheckRow extends StatelessWidget {
  const CloneCheckRow({
    super.key,
    required this.checked,
    required this.label,
    required this.onChanged,
    this.result = false,
  });
  final bool checked, result;
  final String label;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    checked: checked,
    enabled: onChanged != null,
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      borderRadius: BorderRadius.circular(result ? 9 : 3),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: result ? const EdgeInsets.all(8) : EdgeInsets.zero,
        decoration: result
            ? BoxDecoration(
                color: const Color(0xFFF4F8FD),
                borderRadius: BorderRadius.circular(9),
              )
            : null,
        child: Row(
          crossAxisAlignment: result
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: result ? 30 : 18,
              child: Center(
                child: Container(
                  width: result ? 20 : 18,
                  height: result ? 20 : 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: checked
                        ? Color(
                            result ? 0xFF1488F5 : 0xFF0A84FF,
                          ).withValues(alpha: onChanged == null ? .45 : 1)
                        : Colors.white,
                    border: Border.all(
                      color: checked
                          ? Color(result ? 0xFF1488F5 : 0xFF0A84FF)
                          : Color(result ? 0xFFB8C1CF : 0xFFB8BEC8),
                    ),
                  ),
                  child: checked
                      ? Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: result ? 16 : 14,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: result ? 11 : 13,
                  height: result ? 16 / 11 : 20 / 13,
                  color: result
                      ? const Color(0xFF697386)
                      : const Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ClonePrimaryAction extends StatelessWidget {
  const ClonePrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.result = false,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool result, loading;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: NativeActionStyle.decoration(enabled: onPressed != null),
    child: FilledButton(
      onPressed: onPressed,
      style: NativeActionStyle.buttonStyle(context).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 50)),
      ),
      child: loading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            )
          : Text(label, textAlign: TextAlign.center),
    ),
  );
}
