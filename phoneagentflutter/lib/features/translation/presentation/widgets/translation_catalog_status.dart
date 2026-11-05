import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_catalog_providers.dart';

class TranslationCatalogStatus extends ConsumerWidget {
  const TranslationCatalogStatus({super.key, required this.region});
  final String region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(translationCatalogProvider(region));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: result.when(
          loading: () => const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('正在读取所选节点支持的语言…')),
            ],
          ),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('无法读取翻译服务语言目录，尚未验证服务能力'),
              TextButton(
                onPressed: () {
                  if (!context.mounted ||
                      ModalRoute.of(context)?.isCurrent != true) {
                    return;
                  }
                  final current = context.widget;
                  if (current is! TranslationCatalogStatus ||
                      current.region != region) {
                    return;
                  }
                  final latest = ref.read(translationCatalogProvider(region));
                  if (!latest.isLoading && latest.hasError) {
                    ref.invalidate(translationCatalogProvider(region));
                  }
                },
                child: const Text('重试读取语言目录'),
              ),
            ],
          ),
          data: (catalog) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                catalog.languages.isEmpty
                    ? '此节点未返回支持语言'
                    : '此节点支持 ${catalog.languages.length} 种语言',
              ),
              if (catalog.languages.isNotEmpty)
                Text(catalog.languages.map((item) => item.label).join(' · ')),
              const SizedBox(height: 8),
              const Text('目录查询成功不代表模型、音频或电话已就绪。'),
            ],
          ),
        ),
      ),
    );
  }
}
