import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/outbound_number_providers.dart';
import '../../../../app/settings_providers.dart';
import '../pages/outbound_number_route.dart';
import '../../data/preview_outbound_number_repository.dart';

class OutboundPreviewPage extends StatefulWidget {
  const OutboundPreviewPage({super.key, required this.repository});
  final PreviewOutboundNumberRepository repository;
  @override
  State<OutboundPreviewPage> createState() => _OutboundPreviewPageState();
}

class _OutboundPreviewPageState extends State<OutboundPreviewPage> {
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      developerModeProvider.overrideWith((_) => true),
      outboundNumberRepositoryProvider.overrideWithValue(widget.repository),
    ],
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('模拟保存/删除失败'),
              value: widget.repository.failWrite,
              onChanged: (value) =>
                  setState(() => widget.repository.failWrite = value),
            ),
            const Expanded(child: OutboundNumberRoute(preview: true)),
          ],
        ),
      ),
    ),
  );
}
