import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_access_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import 'translation_model_sheet.dart';

Future<void> showDomesticTranslationModelSheet(BuildContext context) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  final container = ProviderScope.containerOf(context);
  final access = container.read(translationAccessProvider);
  if (access.countryIso != 'CN' || access.forced || access.loading) return;
  await showModalTranslationSelection(
    context,
    container.read(translationSetupProvider.notifier),
    builder: (_) => RouteProviderScope(
      container: container,
      child: const DomesticTranslationModelSheet(),
    ),
  );
}

class DomesticTranslationModelSheet extends ConsumerWidget {
  const DomesticTranslationModelSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => TranslationModelSheet(
    selected: ref.watch(translationSetupProvider).value.domesticModelId,
    region: ref.watch(translationSetupProvider).value.region,
    domestic: true,
  );
}
