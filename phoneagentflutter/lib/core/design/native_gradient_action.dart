import 'package:flutter/material.dart';

enum NativeActionTone { primary, secondary, danger }

/// FinalActionButton / AISettingsGradientActionButton shared presentation.
class NativeGradientAction extends StatelessWidget {
  const NativeGradientAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = NativeActionTone.primary,
    this.actionKey,
  });
  final String label;
  final VoidCallback? onPressed;
  final NativeActionTone tone;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = !enabled
        ? const [Color(0xFFEEF2F7), Color(0xFFE8EDF5)]
        : switch (tone) {
            NativeActionTone.primary => const [
              Color(0xFF0A84FF),
              Color(0xFF0071EB),
            ],
            NativeActionTone.secondary => const [
              Color(0xFFF2F4F7),
              Color(0xFFE8ECF2),
            ],
            NativeActionTone.danger => const [
              Color(0xFFF36E68),
              Color(0xFFE14D46),
            ],
          };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: enabled ? null : Border.all(color: const Color(0xFFDCE4EF)),
      ),
      child: TextButton(
        key: actionKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          foregroundColor: tone == NativeActionTone.secondary
              ? const Color(0xFF344054)
              : Colors.white,
          disabledForegroundColor: const Color(0xFF9CA7B5),
          textStyle: TextStyle(
            fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
            fontSize: 15,
            height: 20 / 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
