import 'package:flutter/material.dart';

const _backdropHeight = 154.0;

/// V66's API29 light wash; navigation is painted separately above it.
class NativeNavigationBackdrop extends StatelessWidget {
  const NativeNavigationBackdrop({
    super.key,
    required this.child,
    required this.contentInset,
    this.visible = true,
  });

  final Widget child;
  final double contentInset;
  final bool visible;

  static double contentInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_NavigationContentInset>()
          ?.value ??
      0;

  static double viewportInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_NavigationContentInset>()
          ?.viewportInset ??
      0;

  static double homeContentInsetOf(BuildContext context) {
    final inset = contentInsetOf(context);
    // V66 home: 120 list padding + 16 quick-card padding, versus 128 elsewhere.
    return inset == 0 ? 0 : inset + 8;
  }

  @override
  Widget build(BuildContext context) {
    final page = _NavigationContentInset(
      // Normal navigation is 110; pages own 16, giving V66's total 128.
      value: visible ? contentInset + 2 : 0,
      viewportInset: visible ? contentInset : 0,
      child: child,
    );
    if (!visible) return page;
    return Stack(
      fit: StackFit.expand,
      children: [
        page,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _backdropHeight,
          child: IgnorePointer(
            child: ClipRect(
              child: const DecoratedBox(
                key: ValueKey('navigation-background-wash'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00F8F9FC),
                      Color(0x14F8F9FC),
                      Color(0x52F8F9FC),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationContentInset extends InheritedWidget {
  const _NavigationContentInset({
    required this.value,
    required this.viewportInset,
    required super.child,
  });
  final double value, viewportInset;
  @override
  bool updateShouldNotify(_NavigationContentInset oldWidget) =>
      value != oldWidget.value || viewportInset != oldWidget.viewportInset;
}
