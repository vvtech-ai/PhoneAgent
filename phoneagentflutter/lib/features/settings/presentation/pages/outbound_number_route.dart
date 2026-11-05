import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/outbound_number_providers.dart';
import '../../../../app/settings_providers.dart';
import 'outbound_number_page.dart';

class OutboundNumberRoute extends ConsumerWidget {
  const OutboundNumberRoute({super.key, this.preview = false});
  final bool preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(developerModeProvider)) {
      return Scaffold(
        appBar: const NativePageAppBar(title: '固定外呼号码'),
        body: const Center(child: Text('开发者入口尚未解锁')),
      );
    }
    final state = ref.watch(outboundNumberProvider);
    final controller = ref.read(outboundNumberProvider.notifier);
    return OutboundNumberPage(
      key: ObjectKey(controller),
      state: state,
      preview: preview,
      onEdit: controller.edit,
      onLoad: () => controller.load(force: true),
      onSave: controller.save,
      onDelete: controller.delete,
    );
  }
}
