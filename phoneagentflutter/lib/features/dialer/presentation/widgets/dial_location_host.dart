import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../translation/domain/translation_location.dart';
import '../../domain/dial_country.dart';
import 'dial_country_rows.dart';

class DialLocationHost extends ConsumerStatefulWidget {
  const DialLocationHost({
    super.key,
    required this.onSelected,
    this.hideWhenSimulated = true,
  });
  final ValueChanged<String> onSelected;
  final bool hideWhenSimulated;

  @override
  ConsumerState<DialLocationHost> createState() => _DialLocationHostState();
}

class _DialLocationHostState extends ConsumerState<DialLocationHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (mounted &&
        value == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      ref.read(translationLocationProvider.notifier).resumeAfterSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideWhenSimulated &&
        ref.watch(
          translationSetupProvider.select(
            (state) => state.value.simulatedCountryIso.isNotEmpty,
          ),
        )) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(translationLocationProvider);
    final controller = ref.read(translationLocationProvider.notifier);
    final iso = state.trusted?.countryIso;
    final country = iso == null ? null : dialCountry(iso);
    var selectionFinished = false;
    void selectCountry() {
      if (selectionFinished ||
          state.busy ||
          country == null ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      selectionFinished = true;
      widget.onSelected(country.iso);
    }

    final blocked = state.status == TranslationLocationStatus.blocked;
    final message = switch (state.status) {
      TranslationLocationStatus.loading => '正在读取位置缓存…',
      TranslationLocationStatus.locating => '正在获取当前位置或等待定位权限…',
      TranslationLocationStatus.denied => '未获得定位权限，点击重试',
      TranslationLocationStatus.blocked => '位置权限已关闭，请前往设置',
      TranslationLocationStatus.unavailable =>
        '当前平台不支持获取位置，请在 Android 或 iOS 中使用',
      TranslationLocationStatus.failed => '无法确定当前位置，请检查系统定位后重试',
      _ => iso == null ? '点击获取当前位置' : '定位不会自动更改所选区号',
    };
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.cancel();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: country == null
                    ? const Color(0x093C3C43)
                    : const Color(0x0A0A84FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: country == null
                      ? const Color(0x1A3C3C43)
                      : const Color(0x290A84FF),
                ),
              ),
              child: Semantics(
                container: country != null,
                button: country != null,
                enabled: country == null ? null : !state.busy,
                label: country == null
                    ? null
                    : '${state.cached ? '上次可信位置' : '当前位置'}，${country.name}，${country.code}',
                onTap: country == null || state.busy ? null : selectCountry,
                excludeSemantics: country != null,
                child: InkWell(
                  key: iso == null ? null : const Key('dial-location-select'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: state.busy
                      ? null
                      : country != null
                      ? selectCountry
                      : iso != null
                      ? null
                      : blocked && !controller.androidNativeParity
                      ? controller.openSettings
                      : controller.requestLocation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (country != null)
                          DialCountryFlag(country: country)
                        else
                          const Text(
                            '●',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF0A84FF),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _description(
                            context,
                            state,
                            country,
                            iso,
                            message,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (country != null)
                          Text(
                            country.code,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A3A7A),
                            ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0x140A84FF),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: TextButton(
                              key: const Key('dial-location-request'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                foregroundColor: const Color(0xFF0A84FF),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: state.busy
                                  ? null
                                  : blocked && !controller.androidNativeParity
                                  ? controller.openSettings
                                  : controller.requestLocation,
                              child: Text(
                                state.busy
                                    ? '获取中'
                                    : blocked
                                    ? '前往设置'
                                    : '获取',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (state.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.error.startsWith('读取位置缓存'))
              TextButton(
                onPressed: state.busy ? null : controller.load,
                child: const Text('重试读取缓存'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _description(
    BuildContext context,
    TranslationLocationState state,
    DialCountry? country,
    String? iso,
    String message,
  ) {
    final caption = Text(
      state.cached ? '上次可信位置' : '当前位置',
      style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73)),
    );
    final title = Text(
      country?.name ?? (iso == null ? message : '$iso · 暂不支持该地区区号'),
      key: const Key('dial-location-message'),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: country == null
            ? const Color(0xFF667085)
            : const Color(0xFF111318),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(15) > 19 ||
            constraints.maxWidth < 150) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption, const SizedBox(height: 4), title],
          );
        }
        return Row(
          children: [
            caption,
            const SizedBox(width: 10),
            Expanded(child: title),
          ],
        );
      },
    );
  }
}
