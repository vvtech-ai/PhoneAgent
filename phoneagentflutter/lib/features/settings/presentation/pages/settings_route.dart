import 'package:flutter/material.dart';
import '../../../../core/widgets/route_provider_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/call_model_refresh_providers.dart';
import '../widgets/settings_model_summary.dart';
import '../../../../app/settings_providers.dart';
import '../../../../app/invite_providers.dart';
import '../../../invite/presentation/pages/invite_activity_route.dart';
import '../../../auth/presentation/controller/auth_providers.dart';
import 'about_route.dart';
import '../../../support_feedback/presentation/feedback_route.dart';
import '../../../home/presentation/pages/home_card_preferences_route.dart';
import '../../../memory/presentation/pages/memory_settings_page.dart';
import '../widgets/logout_dialog.dart';
import 'developer_tools_route.dart';
import 'original_audio_page.dart';
import 'settings_page.dart';
import '../../../trusted_caller/presentation/pages/trusted_caller_settings_entry.dart';

class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({
    super.key,
    required this.onIdentity,
    required this.onModels,
  });
  final VoidCallback onIdentity, onModels;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(originalAudioControllerProvider);
    final models = ref.watch(callModelControllerProvider);
    void push(Widget page) {
      final container = ProviderScope.containerOf(context);
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  RouteProviderScope(container: container, child: page),
            ),
          )
          .then((_) {
            if (context.mounted) ref.read(callModelRefreshProvider)();
            if (page is InviteActivityRoute && context.mounted) {
              ref.invalidate(inviteAvailabilityProvider);
            }
          });
    }

    return TrustedCallerSettingsEntry(
      builder: (context, openTrustedCaller) => SettingsPage(
        inviteEntry: ref.watch(inviteEntryPresentationProvider),
        developer: ref.watch(developerModeProvider),
        loginPhone:
            ref.watch(sessionControllerProvider).session?.maskedPhone ?? '未登录',
        modelSummary: models.loading
            ? '加载中'
            : models.error.isNotEmpty
            ? '加载失败'
            : settingsModelSummary(
                models.catalog?.current?.name ?? '',
                models.catalog?.current?.multiplier,
              ),
        originalSummary: '设置',
        onOpen: (destination) {
          switch (destination) {
            case SettingsDestination.identity:
              onIdentity();
            case SettingsDestination.models:
              onModels();
            case SettingsDestination.homeCards:
              push(
                HomeCardPreferencesRoute(
                  ownerEpoch: ref.read(loginEpochProvider),
                ),
              );
            case SettingsDestination.memory:
              push(const MemorySettingsPage());
            case SettingsDestination.originalAudio:
              push(const OriginalAudioPage());
            case SettingsDestination.invite:
              push(const InviteActivityRoute(title: '邀请好友'));
            case SettingsDestination.trustedCaller:
              openTrustedCaller();
            case SettingsDestination.logout:
              showLogoutConfirmation(
                context,
                ref.read(sessionControllerProvider.notifier).signOut,
              );
            case SettingsDestination.about:
              push(const AboutRoute());
            case SettingsDestination.feedback:
              push(const FeedbackRoute());
            case SettingsDestination.developer:
              push(const DeveloperToolsRoute());
          }
        },
      ),
    );
  }
}
