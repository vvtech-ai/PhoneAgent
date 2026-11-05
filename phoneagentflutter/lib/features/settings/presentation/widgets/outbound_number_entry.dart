import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/native_setting_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/outbound_number_providers.dart';
import '../../../../app/settings_providers.dart';
import '../controller/outbound_number_controller.dart';
import '../pages/outbound_number_route.dart';

class OutboundNumberEntry extends ConsumerWidget {
  const OutboundNumberEntry({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(outboundNumberProvider);
    final saved = state.saved;
    final description = state.operation == OutboundOperation.loading
        ? '正在读取当前固定外呼号码'
        : state.error ??
              (saved == null || saved.number.isEmpty
                  ? '尚未配置固定外呼号码'
                  : saved.configured
                  ? '当前生效：${saved.masked}'
                  : '已保存但后端标记为未配置：${saved.masked}');
    return NativeSettingCard(
      title: '固定外呼号码',
      subtitle: description,
      value: '编辑',
      onTap: () async {
        if (!context.mounted ||
            ModalRoute.of(context)?.isCurrent != true ||
            !ref.read(developerModeProvider)) {
          return;
        }
        final container = ProviderScope.containerOf(context);
        final controller = ref.read(outboundNumberProvider.notifier);
        controller.discardDraft();
        controller.load(force: true);
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => UncontrolledProviderScope(
              container: container,
              child: const OutboundNumberRoute(),
            ),
          ),
        );
        if (context.mounted &&
            ModalRoute.of(context)?.isCurrent == true &&
            ref.read(developerModeProvider) &&
            result != null &&
            identical(controller, ref.read(outboundNumberProvider.notifier))) {
          showNativeNotice(
            context,
            result,
            duration: const Duration(seconds: 4),
          );
        }
      },
    );
  }
}
