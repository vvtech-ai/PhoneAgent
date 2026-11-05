import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_directory_providers.dart';
import '../../../../app/translation_location_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../../core/design/native_page_header.dart';
import '../../../dialer/domain/dial_country.dart';
import '../../../translation/domain/translation_model_selection.dart';

String developerCountryLabel(String iso) {
  final name = dialCountry(iso)?.name;
  return name == null ? iso : '$name ($iso)';
}

/// Returns null on back, empty on automatic, or a directory ISO on selection.
class DeveloperCountryPicker extends ConsumerStatefulWidget {
  const DeveloperCountryPicker({super.key});
  @override
  ConsumerState<DeveloperCountryPicker> createState() =>
      _DeveloperCountryPickerState();
}

class _DeveloperCountryPickerState
    extends ConsumerState<DeveloperCountryPicker> {
  String query = '';
  bool finished = false;
  void _finish(String iso) {
    if (finished || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    finished = true;
    Navigator.pop(context, iso);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.invalidate(translationDirectoryProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(translationDirectoryProvider);
    final directory = !snapshot.isLoading && !snapshot.hasError
        ? snapshot.valueOrNull
        : null;
    final selected = ref
        .watch(translationSetupProvider)
        .value
        .simulatedCountryIso;
    final effective =
        ref.watch(effectiveTranslationLocationProvider).trusted?.countryIso ??
        '';
    final search = query.trim().toLowerCase();
    final countries =
        directory?.countries
            .where(
              (c) =>
                  c.iso.toLowerCase().contains(search) ||
                  c.name.toLowerCase().contains(search),
            )
            .toList() ??
        [];
    countries.sort((a, b) {
      final name = a.name.compareTo(b.name);
      return name == 0 ? a.iso.compareTo(b.iso) : name;
    });
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            NativePageHeader(
              title: '主叫所在国家',
              onBack: () => Navigator.maybePop(context),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                '一次使用一个主叫国家，可随时切换。节点和模型由该国家配置自动带出；拨号页选择的是被叫国家。',
                style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: TextField(
                key: const Key('developer-country-search'),
                maxLines: 1,
                style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: '搜索国家名称或 ISO 代码',
                  hintStyle: TextStyle(color: Color(0xFF98A2B3)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (directory == null || directory.countries.isEmpty)
                    TextButton(
                      onPressed: snapshot.isLoading
                          ? null
                          : () => ref.invalidate(translationDirectoryProvider),
                      child: Text(
                        snapshot.isLoading
                            ? '正在加载国家与节点模型…'
                            : snapshot.hasError
                            ? '国家与节点模型加载失败，点击重试'
                            : '尚未加载国家与节点模型，点击重试',
                      ),
                    ),
                  if (search.isEmpty)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                      dense: true,
                      titleTextStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: selected.isEmpty
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: const Color(0xFF111111),
                      ),
                      subtitleTextStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                      title: Text('自动定位${selected.isEmpty ? ' ✓' : ''}'),
                      subtitle: Text(
                        effective.isEmpty
                            ? '由设备定位确定主叫国家'
                            : developerCountryLabel(effective),
                      ),
                      onTap: () => _finish(''),
                    ),
                  for (final country in countries)
                    Builder(
                      builder: (context) {
                        final count = country.modelIds.where((id) {
                          final model = directory!.model(id);
                          return model != null &&
                              (translationModelSupported(
                                    model,
                                    overseas: false,
                                  ) ||
                                  translationModelSupported(
                                    model,
                                    overseas: true,
                                  ));
                        }).length;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 11,
                          ),
                          dense: true,
                          titleTextStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: selected == country.iso
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: const Color(0xFF111111),
                          ),
                          subtitleTextStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                          key: ValueKey('developer-country-${country.iso}'),
                          title: Text(
                            '${country.name} (${country.iso})${selected == country.iso ? ' ✓' : ''}',
                          ),
                          subtitle: Text(
                            count > 0
                                ? '节点支持 $count 个模型'
                                : country.nodeEndpoint.isEmpty
                                ? '尚未配置翻译节点'
                                : '节点已配置，尚未绑定可用模型',
                          ),
                          onTap: () => _finish(country.iso),
                        );
                      },
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
