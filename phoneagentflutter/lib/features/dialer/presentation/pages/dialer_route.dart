import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../../../app/dial_contact_providers.dart';
import '../../../../app/dial_recent_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../translation/presentation/controller/translation_setup_controller.dart';
import '../../../translation/presentation/pages/translation_dialer_route.dart';
import '../../data/preview_dial_recent_source.dart';
import '../../domain/dial_recent_call.dart';
import '../controller/dial_recent_controller.dart';
import '../../data/preview_dial_contacts.dart';
import '../../../contacts/data/lpinyin_contact_dictionary.dart';
import '../../domain/dial_contact_suggestion.dart';
import '../controller/dial_contacts_controller.dart';

Future<void> openDialer(
  BuildContext context, {
  String? number,
  String name = '',
  bool preview = false,
  bool translationEntry = false,
}) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
  final container = ProviderScope.containerOf(context);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RouteProviderScope(
        container: container,
        child: DialerRoute(
          number: number,
          name: name,
          preview: preview,
          translationEntry: translationEntry,
        ),
      ),
    ),
  );
}

/// Compatibility composition for callers; there is only one dialer page.
class DialerRoute extends StatelessWidget {
  const DialerRoute({
    super.key,
    this.number,
    this.name = '',
    this.preview = false,
    this.translationEntry = false,
  });
  final String? number;
  final String name;
  final bool preview, translationEntry;
  @override
  Widget build(BuildContext context) {
    final page = TranslationDialerRoute(
      number: number,
      name: name,
      preview: preview,
      translationEntry: translationEntry,
    );
    if (!preview) return page;
    return ProviderScope(
      overrides: [
        dialRecentProvider.overrideWith((ref) {
          final controller = DialRecentController(
            const PreviewDialRecentSource(DialRecentSource.system),
            const PreviewDialRecentSource(DialRecentSource.app),
          );
          controller.load();
          return controller;
        }),
        translationSetupProvider.overrideWith(
          (ref) => TranslationSetupController(),
        ),
        dialContactsProvider.overrideWith((ref) {
          final controller = DialContactsController(
            PreviewDialContacts(),
            const DialSuggestionPolicy(LpinyinContactDictionary()),
          );
          controller.load();
          return controller;
        }),
      ],
      child: page,
    );
  }
}
