import 'package:flutter/material.dart';
import '../../domain/translation_preferences.dart';

class TranslationOptions extends StatelessWidget {
  const TranslationOptions({
    super.key,
    required this.state,
    required this.onEnabled,
    required this.onPrompt,
    required this.onLanguage,
  });
  final TranslationPreferences state;
  final ValueChanged<bool> onEnabled, onPrompt;
  final ValueChanged<bool> onLanguage;
  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Column(
      children: [
        const SizedBox(height: 14),
        NativeTranslationPresetSwitchRow(
          key: const Key('translation-enabled'),
          title: '实时翻译',
          subtitle: '关闭后将作为普通电话呼叫',
          value: state.enabled,
          onChanged: onEnabled,
        ),
        const SizedBox(height: 14),
        NativeTranslationPresetSwitchRow(
          key: const Key('translation-prompt'),
          title: '拨号前打开本提示',
          value: state.prompt,
          onChanged: onPrompt,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final caller in [true, false]) ...[
              if (!caller) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      caller ? '我方' : '对方',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF30323A),
                      ),
                    ),
                    const SizedBox(height: 7),
                    OutlinedButton(
                      key: ValueKey(
                        caller ? 'translation-caller' : 'translation-peer',
                      ),
                      onPressed: state.enabled
                          ? () => onLanguage(caller)
                          : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xFFF8FAFD),
                        foregroundColor: const Color(0xFF202228),
                        disabledForegroundColor: const Color(0xFFB7BAC2),
                        side: const BorderSide(color: Color(0xFFDCE4EF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: ios ? 12 : 14,
                        ),
                        textStyle: TextStyle(
                          fontFamily: Theme.of(
                            context,
                          ).textTheme.labelLarge?.fontFamily,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              translationLanguage(
                                caller ? state.caller : state.peer,
                              ).label,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: Color(0xFF98A2B3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The whole row owns the tap, so the 34x20 visual is never a small tap target.
class NativeTranslationPresetSwitchRow extends StatelessWidget {
  const NativeTranslationPresetSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    void toggle() => onChanged?.call(!value);
    return Semantics(
      button: true,
      toggled: value,
      label: title,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : toggle,
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanged == null ? null : toggle,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202228),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: Color(0xFF8A8F9D),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: ios ? 34 : 48,
              height: ios ? 20 : 48,
              child: Center(
                child: CustomPaint(
                  size: const Size(34, 20),
                  painter: _CompactToggle(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactToggle extends CustomPainter {
  const _CompactToggle(this.on);
  final bool on;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 3, 34, 14),
        const Radius.circular(7),
      ),
      Paint()..color = on ? const Color(0xFF34C759) : const Color(0xFFD1D5DB),
    );
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(on ? 24 : 10, 10), radius: 10));
    canvas.drawShadow(circle, const Color(0x2E000000), 2, false);
    canvas.drawPath(circle, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CompactToggle oldDelegate) => on != oldDelegate.on;
}
