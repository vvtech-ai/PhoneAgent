import '../../../../core/design/native_notice.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/native_setting_controls.dart';
import 'native_developer_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/developer_network_providers.dart';
import '../../domain/developer_network_mode.dart';

class DeveloperNetworkControls extends ConsumerWidget {
  const DeveloperNetworkControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(developerNetworkModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '网络状态模拟',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 2),
        NativeDeveloperChoices(
          children: [
            for (final entry in const {
              DeveloperNetworkMode.normal: '正常',
              DeveloperNetworkMode.weak: '弱网',
              DeveloperNetworkMode.offline: '断网',
            }.entries)
              NativeSettingChoice(
                key: ValueKey('developer-network-${entry.key.name}'),
                label: entry.value,
                selected: current == entry.key,
                onTap: () {
                  ref.read(developerNetworkModeProvider.notifier).state =
                      entry.key;
                  dismissNativeNotice();
                  final message = switch (entry.key) {
                    DeveloperNetworkMode.normal => null,
                    DeveloperNetworkMode.weak => '网络信号弱，加载可能较慢',
                    DeveloperNetworkMode.offline => '网络已断开',
                  };
                  if (message != null) {
                    showNativeNotice(
                      context,
                      message,
                      duration: const Duration(seconds: 2),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}
