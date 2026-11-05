import '../controller/translation_location_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../dialer/presentation/pages/dial_country_page.dart';
import '../../../dialer/presentation/widgets/dial_location_host.dart';
import '../../data/preview_translation_location.dart';
import '../../domain/translation_location.dart';

class TranslationLocationPreviewPage extends StatefulWidget {
  const TranslationLocationPreviewPage({super.key});
  @override
  State<TranslationLocationPreviewPage> createState() =>
      _TranslationLocationPreviewPageState();
}

class _TranslationLocationPreviewPageState
    extends State<TranslationLocationPreviewPage> {
  final _source = PreviewTranslationLocation();
  String _selected = 'CN', _scenario = 'US';

  void _choose(String value) => setState(() {
    _scenario = value;
    _source.failRead = value == 'read';
    _source.failWrite = value == 'write';
    _source.result = switch (value) {
      'denied' => const TranslationLocationResult(
        TranslationLocationStatus.denied,
      ),
      'blocked' => const TranslationLocationResult(
        TranslationLocationStatus.blocked,
      ),
      'failed' => const TranslationLocationResult(
        TranslationLocationStatus.failed,
      ),
      _ => TranslationLocationResult(
        TranslationLocationStatus.resolved,
        countryIso: ['US', 'CN', 'DE'].contains(value) ? value : 'JP',
      ),
    };
  });

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      translationLocationSourceProvider.overrideWithValue(_source),
      translationLocationStoreProvider.overrideWithValue(_source),
      // This generic location preview must never read real OS permissions.
      translationLocationProvider.overrideWith((_) {
        final controller = TranslationLocationController(_source, _source);
        controller.load();
        return controller;
      }),
    ],
    child: Builder(
      builder: (scopeContext) => Scaffold(
        appBar: AppBar(title: const Text('当前位置与区号演练')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('MOCK · 不获取真实位置，不打开系统设置，不修改正式偏好'),
            const SizedBox(height: 16),
            Text(
              '手选区号：$_selected',
              key: const Key('location-preview-selected'),
            ),
            const Text('先选模拟结果，再进入国家页点击“获取”；位置成功不会自动选区号。'),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'US': '美国',
                  'CN': '中国',
                  'DE': '未支持区号（德国）',
                  'denied': '权限拒绝',
                  'blocked': '需去设置',
                  'failed': '定位失败',
                  'read': '缓存读取失败',
                  'write': '缓存保存失败',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _scenario == entry.key,
                    onSelected: (_) => _choose(entry.key),
                  ),
              ],
            ),
            FilledButton(
              onPressed: () async {
                final container = ProviderScope.containerOf(scopeContext);
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (pageContext) => UncontrolledProviderScope(
                      container: container,
                      child: DialCountryPage(
                        selected: _selected,
                        location: Column(
                          children: [
                            const Text('MOCK · 合成定位 / 内存缓存'),
                            DialLocationHost(
                              hideWhenSimulated: false,
                              onSelected: (iso) =>
                                  Navigator.pop(pageContext, iso),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                if (mounted) {
                  setState(() {
                    if (result != null) _selected = result;
                  });
                }
              },
              child: const Text('打开国家和地区'),
            ),
            TextButton(
              onPressed: () => setState(() => _source.cached = null),
              child: const Text('清除本次模拟缓存'),
            ),
            Text('合成请求：${_source.requests}；模拟设置：${_source.settings}'),
            const Text('返回重开可验证缓存；失败场景保留上次可信位置。真实平台权限和定位仍须集中验收。'),
          ],
        ),
      ),
    ),
  );
}
