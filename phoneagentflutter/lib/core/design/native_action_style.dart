import 'package:flutter/material.dart';

enum NativeActionTone { primary, secondary, danger }

/// C03 presentation only; each control owns its callback and availability.
abstract final class NativeActionStyle {
  static BoxDecoration decoration({
    required bool enabled,
    NativeActionTone tone = NativeActionTone.primary,
    Color? backgroundColor,
  }) {
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
    return BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: enabled ? backgroundColor : null,
      gradient: enabled && backgroundColor != null
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
      border: enabled ? null : Border.all(color: const Color(0xFFDCE4EF)),
    );
  }

  static ButtonStyle buttonStyle(
    BuildContext context, {
    NativeActionTone tone = NativeActionTone.primary,
    Color? foregroundColor,
  }) => TextButton.styleFrom(
    minimumSize: const Size(0, 50),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    side: BorderSide.none,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    backgroundColor: Colors.transparent,
    disabledBackgroundColor: Colors.transparent,
    foregroundColor:
        foregroundColor ??
        (tone == NativeActionTone.secondary
            ? const Color(0xFF344054)
            : Colors.white),
    disabledForegroundColor: const Color(0xFF9CA7B5),
    textStyle: TextStyle(
      fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Applies C03 to an existing plain button without owning its callback.
class NativeActionSurface extends StatelessWidget {
  const NativeActionSurface({
    super.key,
    required this.child,
    this.tone = NativeActionTone.primary,
  });
  final ButtonStyleButton child;
  final NativeActionTone tone;

  @override
  Widget build(BuildContext context) {
    final style = NativeActionStyle.buttonStyle(context, tone: tone);
    return DecoratedBox(
      decoration: NativeActionStyle.decoration(
        enabled: child.enabled,
        tone: tone,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          filledButtonTheme: FilledButtonThemeData(style: style),
          outlinedButtonTheme: OutlinedButtonThemeData(style: style),
          textButtonTheme: TextButtonThemeData(style: style),
        ),
        child: child,
      ),
    );
  }
}
