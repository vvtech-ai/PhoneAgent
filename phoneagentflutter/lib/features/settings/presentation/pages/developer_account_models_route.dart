import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/domestic_translation_settings_providers.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../../core/design/native_gradient_action.dart';
import '../../../../core/design/native_notice.dart';
import '../widgets/native_developer_section.dart';

/// Account preference debugging; deliberately never changes dial model IDs.
class DeveloperAccountModelsRoute extends ConsumerStatefulWidget {
  const DeveloperAccountModelsRoute({super.key});
  @override
  ConsumerState<DeveloperAccountModelsRoute> createState() =>
      _DeveloperAccountModelsRouteState();
}

class _DeveloperAccountModelsRouteState
    extends ConsumerState<DeveloperAccountModelsRoute> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.invalidate(domesticTranslationSettingsProvider);
    });
  }

  Future<void> _select(String id, String name) async {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final controller = ref.read(domesticTranslationSettingsProvider.notifier);
    await controller.selectModel(id);
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        !identical(
          controller,
          ref.read(domesticTranslationSettingsProvider.notifier),
        )) {
      return;
    }
    final state = ref.read(domesticTranslationSettingsProvider);
    if (state.error.isNotEmpty) {
      showNativeNotice(
        context,
        '同声传译模型切换失败，请检查网络或本地服务连接',
        duration: const Duration(seconds: 2),
      );
    } else if (state.catalog?.activeWireId == id) {
      showNativeNotice(
        context,
        '翻译通话模型已切换为 $name',
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = ref
        .watch(effectiveTranslationLocationProvider)
        .trusted
        ?.countryIso;
    final state = ref.watch(domesticTranslationSettingsProvider);
    final controller = ref.read(domesticTranslationSettingsProvider.notifier);
    final region = country == null
        ? '待确认'
        : country == 'CN'
        ? '国内'
        : '海外';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            NativePageHeader(
              title: '账号翻译模型（调试）',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                children: [
                  const SizedBox(height: 14),
                  NativeDeveloperSection(
                    title: '',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '账号模型偏好仅供调试；拨号页选中的模型用于发起通话',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '当前地区：$region',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (state.loading && state.catalog == null)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('正在读取翻译模型状态...'),
                    ),
                  if (country == null)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('无法确定主叫地区，请定位或设置模拟国家后重试'),
                    ),
                  if (state.error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        state.error,
                        style: const TextStyle(color: Color(0xFFE14D46)),
                      ),
                    ),
                  for (final option in state.catalog?.options ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xCCFFFFFF),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: option.active
                                ? const Color(0x55007AFF)
                                : const Color(0xC7FFFFFF),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.displayName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        option.statusMessage.isEmpty
                                            ? '待检查'
                                            : option.statusMessage,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6E6E73),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: option.active
                                        ? const Color(0x1A007AFF)
                                        : const Color(0xFFF2F4F7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    option.active
                                        ? '账号偏好'
                                        : option.available
                                        ? '可设置'
                                        : '暂不可用',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: option.active
                                          ? const Color(0xFF0A84FF)
                                          : const Color(0xFF667085),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '配置状态：${option.configured ? '已配置' : '缺少配置'} · 可用性：${option.available ? '可用' : '不可用'}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                            const SizedBox(height: 14),
                            NativeGradientAction(
                              tone: option.active
                                  ? NativeActionTone.secondary
                                  : NativeActionTone.primary,
                              onPressed:
                                  !state.busy &&
                                      option.available &&
                                      !option.active
                                  ? () => _select(
                                      option.wireId,
                                      option.displayName,
                                    )
                                  : null,
                              label: state.switching && option.active
                                  ? '设置中...'
                                  : option.active
                                  ? '当前账号偏好'
                                  : !option.available
                                  ? '暂不可设置'
                                  : '设为账号偏好',
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  NativeGradientAction(
                    tone: NativeActionTone.secondary,
                    onPressed: !state.busy && country != null
                        ? controller.load
                        : null,
                    label: state.loading ? '刷新中...' : '刷新状态',
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
