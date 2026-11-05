import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/native_detail_header.dart';
import '../../../../app/translation_access_providers.dart';
import '../controller/translation_setup_controller.dart';
import '../widgets/translation_access_message.dart';
import '../widgets/translation_catalog_status.dart';
import 'translation_selection_pages.dart';

class TranslationSettingsRoute extends ConsumerWidget {
  const TranslationSettingsRoute({super.key, required this.controller});
  final TranslationSetupController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(translationAccessProvider);
    if (!access.showOverseasSettings) {
      return Scaffold(
        backgroundColor: const Color(0xFFFBFCFD),
        body: SafeArea(
          child: Column(
            children: [
              NativeDetailHeader(
                title: '海外实时翻译',
                onBack: () {
                  if (context.mounted &&
                      ModalRoute.of(context)?.isCurrent == true) {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(translationAccessMessage(access)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return TranslationSettingsPage(
      controller: controller,
      canEdit: () =>
          context.mounted &&
          ref.read(translationAccessProvider).showOverseasSettings,
      serviceStatusBuilder: (region) =>
          TranslationCatalogStatus(region: region),
    );
  }
}
