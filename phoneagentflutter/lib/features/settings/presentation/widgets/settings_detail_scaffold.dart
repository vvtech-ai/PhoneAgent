import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_page_background.dart';

/// Shared settings surface; system safe areas remain platform-owned.
class SettingsDetailScaffold extends StatelessWidget {
  const SettingsDetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });
  final String title;
  final Widget body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FC),
    body: NativePageBackground(
      child: SafeArea(
        child: Column(
          children: [
            NativePageHeader(
              title: title,
              onBack: () => Navigator.maybePop(context),
              trailing: actions.isEmpty
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    ),
  );
}
