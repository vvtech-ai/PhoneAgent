import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/business_providers.dart';
import '../../../../app/home_card_preference_providers.dart';
import '../../domain/home_card_preferences.dart';
import '../widgets/skill_card_restore_dialog.dart';
import '../widgets/skill_card_settings_screen.dart';

class HomeCardPreferencesRoute extends ConsumerWidget {
  const HomeCardPreferencesRoute({super.key, required this.ownerEpoch});
  final int? ownerEpoch;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epoch = ref.watch(loginEpochProvider);
    ref.listen(loginEpochProvider, (_, next) {
      if (next != ownerEpoch) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    if (epoch != ownerEpoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            ModalRoute.of(context)?.isCurrent == true &&
            Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return const Scaffold(body: Center(child: Text('账号已切换')));
    }
    final config = ref.watch(homeControllerProvider).config;
    final controller = ref.watch(homeCardPreferenceProvider);
    final cards = HomeCardPreferencePolicy.ordered(
      config.cards,
      controller.preferences,
    );
    return SkillCardSettingsScreen(
      cards: cards,
      preferences: controller.preferences,
      ready: controller.ready && !controller.readFailed,
      readFailed: controller.readFailed,
      notice: controller.notice,
      onBack: () => Navigator.maybePop(context),
      onRetry: controller.retry,
      onVisible: (id, visible) =>
          controller.visibility(config.cards, id, visible),
      onReorder: (from, to) {
        final ids = cards.map((card) => card.id).toList();
        ids.insert(to > from ? to - 1 : to, ids.removeAt(from));
        controller.reorder(config.cards, ids);
      },
      onRestore: () async {
        final confirmed = await confirmSkillCardRestore(context);
        if (confirmed &&
            context.mounted &&
            ref.read(loginEpochProvider) == ownerEpoch) {
          await controller.reset();
        }
      },
    );
  }
}
