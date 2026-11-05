import '../../../../core/design/native_notice.dart';
import 'developer_action_row.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/dial_permission_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../translation/presentation/pages/translation_dialer_route.dart';

class DeveloperPermissionReset extends ConsumerStatefulWidget {
  const DeveloperPermissionReset({super.key});
  @override
  ConsumerState<DeveloperPermissionReset> createState() =>
      _DeveloperPermissionResetState();
}

class _DeveloperPermissionResetState
    extends ConsumerState<DeveloperPermissionReset> {
  bool _opening = false;
  Future<void> _reset() async {
    if (!mounted || _opening || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _opening = true);
    try {
      final setup = ref.read(translationSetupProvider.notifier);
      await setup.load();
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          !setup.mounted ||
          !identical(setup, ref.read(translationSetupProvider.notifier))) {
        return;
      }
      if (!setup.status.ready) {
        showNativeNotice(
          context,
          '翻译配置读取失败，请重试后再重置',
          duration: const Duration(seconds: 2),
        );
        return;
      }
      final memory = ref.read(dialPermissionMemoryProvider);
      await memory.ready;
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          !setup.mounted ||
          !identical(setup, ref.read(translationSetupProvider.notifier)) ||
          !identical(memory, ref.read(dialPermissionMemoryProvider))) {
        return;
      }
      memory.resetLocation();
      setup.enable(true);
      final container = ProviderScope.containerOf(context);
      showNativeNotice(
        context,
        '模拟权限已重置',
        duration: const Duration(seconds: 2),
      );
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => RouteProviderScope(
            container: container,
            child: const TranslationDialerRoute(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => DeveloperActionRow(
    title: '重置所有权限',
    subtitle: '清除模拟权限记录，下次使用重新弹窗',
    action: '重置',
    onPressed: _opening ? null : _reset,
  );
}
