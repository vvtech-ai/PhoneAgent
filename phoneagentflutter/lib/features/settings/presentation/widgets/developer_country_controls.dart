import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../../translation/presentation/widgets/translation_storage_status.dart';
import '../pages/developer_country_picker.dart';
import 'developer_action_row.dart';
import 'native_developer_toggle.dart';

class DeveloperCountryControls extends ConsumerStatefulWidget {
  const DeveloperCountryControls({super.key});
  @override
  ConsumerState<DeveloperCountryControls> createState() =>
      _DeveloperCountryControlsState();
}

class _DeveloperCountryControlsState
    extends ConsumerState<DeveloperCountryControls> {
  bool opening = false;
  String? _pendingCountry;
  Future<void> _select([String? country]) async {
    if (opening || ModalRoute.of(context)?.isCurrent != true) return;
    final controller = ref.read(translationSetupProvider.notifier);
    if (!controller.status.ready) return;
    setState(() => opening = true);
    try {
      final container = ProviderScope.containerOf(context);
      final iso =
          country ??
          await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => RouteProviderScope(
                container: container,
                child: const DeveloperCountryPicker(),
              ),
            ),
          );
      if (!mounted ||
          iso == null ||
          ModalRoute.of(context)?.isCurrent != true ||
          !identical(controller, ref.read(translationSetupProvider.notifier))) {
        return;
      }
      _pendingCountry = iso;
      controller.simulateCountry(iso);
      if (!controller.status.saving) _pendingCountry = null;
      if (iso.isEmpty) {
        ref.read(translationLocationProvider.notifier).refreshAfterPermission();
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(translationSetupProvider, (previous, next) {
      if (_pendingCountry == null || next.saving || previous?.saving != true) {
        return;
      }
      final restoring = _pendingCountry!.isEmpty;
      _pendingCountry = null;
      if (next.error.isNotEmpty &&
          mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        showNativeNotice(
          context,
          restoring ? '恢复自动定位失败' : '模拟定位国家设置失败',
          duration: const Duration(seconds: 2),
        );
      }
    });
    final setup = ref.watch(translationSetupProvider);
    final controller = ref.read(translationSetupProvider.notifier);
    final effective =
        ref.watch(effectiveTranslationLocationProvider).trusted?.countryIso ??
        '';
    final iso = setup.value.simulatedCountryIso;
    final enabled = iso.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!setup.ready || setup.saving || setup.error.isNotEmpty)
          TranslationStorageStatus(controller: controller),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: NativeDeveloperToggle(
            key: const Key('developer-country-simulation'),
            value: enabled,
            title: '模拟国家定位',
            subtitle: enabled
                ? '已开启：模拟 ${developerCountryLabel(iso)}，节点与模型按此国家匹配'
                : effective.isEmpty
                ? '已关闭：使用设备自动定位'
                : '已关闭：使用自动定位（${developerCountryLabel(effective)}）',
            onChanged: setup.ready && !opening
                ? (value) => _select(
                    value ? (effective.isEmpty ? null : effective) : '',
                  )
                : null,
          ),
        ),
        DeveloperActionRow(
          title: '模拟主叫国家',
          subtitle: enabled
              ? '当前模拟 ${developerCountryLabel(iso)}'
              : '未开启模拟定位；选择国家会开启模拟',
          action: '选择 ›',
          onPressed: setup.ready && !opening ? () => _select() : null,
        ),
      ],
    );
  }
}
