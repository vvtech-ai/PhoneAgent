import 'package:flutter/material.dart';

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

/// Shared panel styling with the native platform's presentation interaction.
Future<void> showInviteRulesRoute(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
    return Future<void>.value();
  }
  final reduced = MediaQuery.disableAnimationsOf(context);
  if (Theme.of(context).platform != TargetPlatform.iOS) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      shape: _shape,
      sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
      builder: builder,
    );
  }
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000),
    transitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 300),
    pageBuilder: (routeContext, _, _) => InheritedTheme.captureAll(
      context,
      Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          shape: _shape,
          clipBehavior: Clip.antiAlias,
          child: builder(routeContext),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
