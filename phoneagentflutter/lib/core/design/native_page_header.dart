import 'package:flutter/material.dart';
import 'native_detail_header.dart';

/// Full-page navigation only. The parent owns SafeArea and the background.
class NativePageHeader extends StatelessWidget {
  const NativePageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.showBack = true,
    this.backKey,
    this.backLabel = '返回',
    this.trailing,
    this.backgroundColor,
    this.foregroundColor = const Color(0xFF111111),
  });

  final String title;
  final VoidCallback? onBack;
  final bool showBack;
  final Key? backKey;
  final String backLabel;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final header = NativeDetailHeader(
      title: title,
      onBack: onBack,
      showBack: showBack,
      backKey: backKey,
      backLabel: backLabel,
      trailing: trailing,
      color: foregroundColor,
    );
    return backgroundColor == null
        ? header
        : ColoredBox(color: backgroundColor!, child: header);
  }
}

/// Keeps AppBar's system inset and background, with the page's actual text scale.
class NativePageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NativePageAppBar({
    super.key,
    required this.title,
    required this.textScaler,
    this.onBack,
    this.showBack,
    this.backLabel = '返回',
    this.trailing,
    this.backgroundColor,
  });
  final String title;
  final TextScaler textScaler;
  final VoidCallback? onBack;
  final bool? showBack;
  final String backLabel;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(NativeDetailHeader.heightFor(textScaler));

  @override
  Widget build(BuildContext context) {
    final canReturn = showBack ?? (onBack != null || Navigator.canPop(context));
    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      titleSpacing: 0,
      title: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: NativePageHeader(
          title: title,
          showBack: canReturn,
          backLabel: backLabel,
          onBack:
              onBack ??
              (showBack == null && canReturn
                  ? () => Navigator.maybePop(context)
                  : null),
          trailing: trailing,
        ),
      ),
    );
  }
}
