import 'package:flutter/material.dart';
import 'package:phone_agent/features/settings/domain/outbound_number.dart';
import 'package:phone_agent/features/settings/presentation/controller/outbound_number_controller.dart';
import 'package:phone_agent/features/settings/presentation/pages/outbound_number_page.dart';

/// Only static synthetic presentation. No provider, account, plugin or device IO.
void main() => runApp(const _OutboundReference());

class _OutboundReference extends StatelessWidget {
  const _OutboundReference();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(platform: TargetPlatform.iOS, useMaterial3: true),
    home: const _ReferenceRoot(),
  );
}

class _ReferenceRoot extends StatefulWidget {
  const _ReferenceRoot();
  @override
  State<_ReferenceRoot> createState() => _ReferenceRootState();
}

class _ReferenceRootState extends State<_ReferenceRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const mode = String.fromEnvironment(
        'UI_REFERENCE_OUTBOUND_STATE',
        defaultValue: 'saved',
      );
      final number = mode == 'empty' ? '' : '13800000000';
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => OutboundNumberPage(
            state: OutboundNumberState(
              saved: OutboundNumber(number, configured: number.isNotEmpty),
              draft: number,
              operation: mode == 'loading'
                  ? OutboundOperation.loading
                  : OutboundOperation.idle,
              error: mode == 'error' ? '合成读取失败' : null,
            ),
            onEdit: (_) {},
            onLoad: () async => false,
            onSave: () async => false,
            onDelete: () async => false,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFFF8F9FC),
    body: Center(child: Text('合成外呼配置已返回')),
  );
}
