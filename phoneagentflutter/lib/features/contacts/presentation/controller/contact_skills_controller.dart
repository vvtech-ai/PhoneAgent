import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app_update/domain/app_update.dart';
import '../../../home/domain/home_config.dart';

class ContactSkillsState {
  const ContactSkillsState({
    this.cards = const [],
    this.loading = false,
    this.error = '',
  });
  final List<HomeCard> cards;
  final bool loading;
  final String error;
}

/// A sheet owns its loading lifecycle; it does not refresh the shared homepage.
class ContactSkillsController extends StateNotifier<ContactSkillsState> {
  ContactSkillsController(this._home, this._installed)
    : super(const ContactSkillsState());
  final HomeRepository _home;
  final InstalledAppSource _installed;

  Future<void> load() async {
    if (!mounted || state.loading) return;
    state = ContactSkillsState(cards: state.cards, loading: true);
    try {
      final config = await _home.load();
      if (!mounted) return;
      final candidates = config.cards
          .where(
            (card) =>
                (card.action == HomeAction.translation &&
                    card.status != HomeCardStatus.disabled) ||
                (card.status == HomeCardStatus.enabled &&
                    card.action == HomeAction.skill &&
                    (card.skillId?.trim().isNotEmpty ?? false)),
          )
          .toList();
      var version = '';
      var error = '';
      if (candidates.any(
        (card) =>
            card.action != HomeAction.translation &&
            (card.minimumVersion?.trim().isNotEmpty ?? false),
      )) {
        try {
          version = (await _installed.read()).versionName.trim();
          if (version.isEmpty) {
            throw const FormatException('Missing installed version');
          }
        } catch (_) {
          error = '无法核对当前版本，部分 Skill 暂不可用';
        }
      }
      if (!mounted) return;
      state = ContactSkillsState(
        cards: List.unmodifiable(
          candidates
              .where(
                (card) =>
                    card.action == HomeAction.translation ||
                    card.canEnter(version),
              )
              .map(
                (card) => card.action == HomeAction.translation
                    ? HomeCard(
                        id: card.id,
                        title: '实时翻译',
                        subtitle: card.subtitle,
                        status: card.status,
                        action: card.action,
                        skillId: card.skillId,
                        opening: card.opening,
                        selectedContactOpening: card.selectedContactOpening,
                        minimumVersion: card.minimumVersion,
                        imageUrl: card.imageUrl,
                        defaultVisible: card.defaultVisible,
                      )
                    : card,
              ),
        ),
        error: error,
      );
    } catch (_) {
      if (mounted) {
        state = ContactSkillsState(
          cards: state.cards,
          error: '获取可用 Skill 失败，请重试',
        );
      }
    }
  }
}
