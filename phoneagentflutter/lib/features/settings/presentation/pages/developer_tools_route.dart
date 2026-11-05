import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/developer_list_providers.dart';
import '../../../../app/settings_providers.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_setting_controls.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../widgets/developer_country_controls.dart';
import '../widgets/developer_list_controls.dart';
import '../widgets/developer_network_controls.dart';
import '../widgets/developer_permission_reset.dart';
import '../widgets/native_developer_section.dart';
import '../widgets/outbound_number_entry.dart';
import 'developer_account_models_route.dart';

/// Mirrors the current native formal developer page; previews stay isolated.
class DeveloperToolsRoute extends ConsumerWidget {
  const DeveloperToolsRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(developerModeProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            NativePageHeader(
              title: '开发者功能',
              onBack: () => Navigator.maybePop(context),
            ),
            if (!unlocked)
              const Expanded(child: Center(child: Text('开发者入口尚未解锁')))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  children: [
                    NativeDeveloperSection(
                      title: '列表数据',
                      child: DeveloperListControls(
                        state: ref.watch(developerListControllerProvider),
                        onApply: ref
                            .read(developerListControllerProvider.notifier)
                            .apply,
                      ),
                    ),
                    const NativeDeveloperSection(
                      title: '外呼调试',
                      card: false,
                      child: OutboundNumberEntry(),
                    ),
                    const NativeDeveloperSection(
                      title: '实时翻译',
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: DeveloperCountryControls(),
                    ),
                    const SizedBox(height: 10),
                    NativeSettingCard(
                      title: '账号翻译模型（调试）',
                      subtitle: '查看账号侧模型配置；拨号使用拨号页选中的模型',
                      value: '查看 ›',
                      onTap: () {
                        if (ModalRoute.of(context)?.isCurrent != true ||
                            !ref.read(developerModeProvider)) {
                          return;
                        }
                        final container = ProviderScope.containerOf(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RouteProviderScope(
                              container: container,
                              child: const DeveloperAccountModelsRoute(),
                            ),
                          ),
                        );
                      },
                    ),
                    const NativeDeveloperSection(
                      title: 'V8.8 模拟能力',
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          DeveloperNetworkControls(),
                          DeveloperPermissionReset(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
