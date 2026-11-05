import 'package:flutter/material.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';

/// Effective home cards with synthetic summaries; no accounts or device ports.
class FlutterSettingsReference extends StatelessWidget {
  const FlutterSettingsReference({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NativePageBackground(
      child: SafeArea(
        bottom: false,
        child: SettingsPage(
          onOpen: (_) {},
          developer: true,
          identitySummary: '未填写',
          modelSummary: 'QwenOmni… ×1.0',
          originalSummary: '设置',
        ),
      ),
    ),
  );
}
