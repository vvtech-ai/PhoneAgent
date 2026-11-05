import 'package:flutter/material.dart';
import '../../../../core/design/native_setting_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/agent_location_providers.dart';

/// Observes the Agent's snapshot only. Opening this widget never samples.
class DeveloperLocationSummary extends ConsumerWidget {
  const DeveloperLocationSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(agentLocationProvider);
    return NativeSettingCard(
      key: const Key('developer-agent-location'),
      title: '当前定位',
      subtitle: value?.display ?? '未获取到位置信息',
      value: value == null ? '—' : '✓',
      onTap: null,
    );
  }
}
