import 'home_config.dart';

class HomeCardPreferences {
  const HomeCardPreferences({
    this.order = const [],
    this.visibility = const {},
  });
  final List<String> order;
  final Map<String, bool> visibility;
}

abstract interface class HomeCardPreferenceRepository {
  Future<HomeCardPreferences> read();
  Future<void> save(HomeCardPreferences preferences);
}

abstract final class HomeCardPreferencePolicy {
  static List<HomeCard> ordered(
    List<HomeCard> cards,
    HomeCardPreferences preferences,
  ) {
    final available = cards
        .where((c) => c.status != HomeCardStatus.disabled)
        .toList();
    final byId = {for (final card in available) card.id: card};
    final saved = preferences.order.toSet().where(byId.containsKey).toList();
    return saved.isEmpty
        ? available
        : [
            ...available.where((c) => !saved.contains(c.id)),
            ...saved.map((id) => byId[id]!),
          ];
  }

  static bool visible(HomeCard card, HomeCardPreferences preferences) =>
      preferences.visibility[card.id] ?? card.defaultVisible;
  static List<HomeCard> project(
    List<HomeCard> cards,
    HomeCardPreferences preferences,
  ) => ordered(
    cards,
    preferences,
  ).where((c) => visible(c, preferences)).toList();
  static HomeCardPreferences visibility(
    List<HomeCard> cards,
    HomeCardPreferences current,
    String id,
    bool value,
  ) {
    final card = cards
        .where((c) => c.id == id && c.status != HomeCardStatus.disabled)
        .firstOrNull;
    if (card == null) return current;
    final overrides = Map<String, bool>.of(current.visibility);
    if (value == card.defaultVisible) {
      overrides.remove(id);
    } else {
      overrides[id] = value;
    }
    return HomeCardPreferences(order: current.order, visibility: overrides);
  }

  static HomeCardPreferences move(
    List<HomeCard> cards,
    HomeCardPreferences current,
    int from,
    int to,
  ) {
    final ids = ordered(cards, current).map((c) => c.id).toList();
    if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) {
      return current;
    }
    ids.insert(to, ids.removeAt(from));
    return HomeCardPreferences(order: ids, visibility: current.visibility);
  }
}
