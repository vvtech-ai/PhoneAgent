import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_update_providers.dart';
import '../../../../core/config/migration_previews.dart';
import '../../../app_update/presentation/pages/app_update_preview_page.dart';
import '../../../../app/about_providers.dart';
import '../../../../core/design/native_notice.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import '../../../auth/presentation/controller/legal_document_providers.dart';
import 'about_page.dart';
import 'account_route.dart';

class AboutRoute extends ConsumerWidget {
  const AboutRoute({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool current() =>
        context.mounted && ModalRoute.of(context)?.isCurrent == true;
    final mobileUpdate =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final mockUpdate = kIsWeb && migrationPreviewsEnabled;
    final update = mobileUpdate ? ref.watch(appUpdateControllerProvider) : null;
    final version = ref.watch(aboutVersionProvider);
    return AboutPage(
      onAccount: () {
        if (!current()) return;
        final container = ProviderScope.containerOf(context);
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => RouteProviderScope(
              container: container,
              child: const AccountRoute(),
            ),
          ),
        );
      },
      showUpdate: mobileUpdate || mockUpdate,
      updateTitle: mockUpdate ? '版本更新（MOCK）' : '版本更新',
      updateSummary: update?.busy == true ? '检测中' : '',
      onUpdate: update?.busy == true
          ? null
          : () {
              if (!current()) return;
              if (mockUpdate) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const AppUpdatePreviewPage(),
                  ),
                );
              } else if (mobileUpdate) {
                _checkUpdate(context, ref);
              }
            },
      version: version.when(
        data: (app) =>
            app.versionName.trim().isEmpty ? '' : 'V${app.versionName.trim()}',
        loading: () => '',
        error: (_, __) => '',
      ),
      onDocument: (document) async {
        if (!current()) return;
        try {
          await ref.read(legalDocumentPortProvider).open(document);
        } catch (_) {
          if (context.mounted && current()) {
            showNativeNotice(context, '暂时无法打开协议，请重试');
          }
        }
      },
    );
  }

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appUpdateControllerProvider.notifier);
    if (ref.read(appUpdateControllerProvider).busy) return;
    await controller.check();
    if (!context.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        !controller.mounted ||
        !identical(
          controller,
          ref.read(appUpdateControllerProvider.notifier),
        )) {
      return;
    }
    final state = ref.read(appUpdateControllerProvider);
    if (state.error.isNotEmpty) {
      showNativeNotice(context, state.error);
    } else if (state.release?.hasUpdate == false) {
      showNativeNotice(context, '当前已是最新版本');
    }
  }
}
