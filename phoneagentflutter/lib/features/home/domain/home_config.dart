enum HomeCardStatus { enabled, comingSoon, disabled }

enum HomeAction { skill, translation, genericTask, none }

class HomeSlogan {
  const HomeSlogan(this.id, this.title, this.subtitle);
  final String id, title, subtitle;
}

class HomeCard {
  const HomeCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.action,
    this.skillId,
    this.opening = '',
    this.selectedContactOpening,
    this.minimumVersion,
    this.imageUrl,
    this.defaultVisible = true,
  });
  final String id, title, subtitle, opening;
  final String? skillId, minimumVersion, imageUrl, selectedContactOpening;
  final HomeCardStatus status;
  final HomeAction action;
  final bool defaultVisible;

  bool supports(String version) {
    if (minimumVersion == null || minimumVersion!.isEmpty) return true;
    List<int>? parse(String v) {
      final parts = v
          .trim()
          .split('-')
          .first
          .split('.')
          .map(int.tryParse)
          .toList();
      return parts.any((p) => p == null || p < 0) ? null : parts.cast<int>();
    }

    final current = parse(version), minimum = parse(minimumVersion!);
    if (current == null || minimum == null) return false;
    final count = current.length > minimum.length
        ? current.length
        : minimum.length;
    for (var i = 0; i < count; i++) {
      final a = i < current.length ? current[i] : 0;
      final b = i < minimum.length ? minimum[i] : 0;
      if (a != b) return a > b;
    }
    return true;
  }

  bool canEnter(String version) =>
      status == HomeCardStatus.enabled &&
      action != HomeAction.none &&
      supports(version);
}

class HomeConfig {
  const HomeConfig(
    this.version,
    this.slogans,
    this.cards, {
    this.builtin = false,
  });
  final String version;
  final List<HomeSlogan> slogans;
  final List<HomeCard> cards;
  final bool builtin;
}

abstract interface class HomeRepository {
  Future<HomeConfig> load();
  Future<HomeSlogan> nextSlogan(HomeConfig config);
}

abstract interface class HomeRepositoryStatus {
  bool get loadFailed;
}
