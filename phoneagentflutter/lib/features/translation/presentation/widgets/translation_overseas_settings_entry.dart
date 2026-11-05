import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/translation_access_providers.dart';
import '../../../../app/translation_providers.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../controller/translation_setup_controller.dart';
import '../pages/translation_selection_pages.dart';
import '../pages/translation_settings_route.dart';

/// Owns navigation from the presets route, preserving its original container.
class TranslationOverseasSettingsEntry extends ConsumerWidget {
  const TranslationOverseasSettingsEntry({
    super.key,
    required this.controller,
    required this.preview,
    required this.busy,
  });
  final TranslationSetupController controller;
  final bool preview, busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: busy
        ? null
        : () {
            if (!context.mounted ||
                ModalRoute.of(context)?.isCurrent != true ||
                !controller.mounted ||
                !controller.status.ready) {
              return;
            }
            if (!identical(
                  ref.read(translationSetupProvider.notifier),
                  controller,
                ) ||
                (!preview &&
                    !ref
                        .read(translationAccessProvider)
                        .showOverseasSettings)) {
              return;
            }
            final container = ProviderScope.containerOf(context);
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => RouteProviderScope(
                  container: container,
                  child: preview
                      ? TranslationSettingsPage(controller: controller)
                      : TranslationSettingsRoute(controller: controller),
                ),
              ),
            );
          },
    child: const Text('海外模型与服务区域'),
  );
}
