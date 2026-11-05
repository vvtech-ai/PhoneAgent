import '../domain/home_config.dart';

class HomeConfigMapper {
  const HomeConfigMapper(this.base);
  final Uri base;

  HomeConfig parse(Map<String, dynamic> dto) {
    if (dto['version'] != 'home-config-v1' ||
        text(dto, 'publicationStatus').toLowerCase() != 'published') {
      throw const FormatException('Unpublished home config');
    }
    text(dto, 'configId');
    final version = text(dto, 'configVersion');
    final home = object(dto['home']);
    final skills = <String, String>{};
    final contactOpenings = <String, String>{};
    for (final item in list(dto['skillRefs'] ?? [])) {
      final skill = object(item);
      final id = optional(skill, 'id'), opening = optional(skill, 'opening');
      if (id != null && opening != null) skills[id] = opening;
      final contactOpening = optional(skill, 'selectedContactOpening');
      if (id != null && contactOpening != null) {
        contactOpenings[id] = contactOpening;
      }
    }
    final slogans = ordered(home['slogans'], (item) {
      if (!{'enabled', 'disabled'}.contains(item['status'])) {
        throw const FormatException('Invalid slogan status');
      }
      if (item['status'] == 'disabled') return null;
      return HomeSlogan(
        text(item, 'id'),
        text(item, 'line1', max: 10),
        text(item, 'line2', max: 20),
      );
    });
    final cards = ordered(home['cards'], (item) {
      final id = text(item, 'id');
      final actionDto = object(item['entryAction']);
      final action = switch (actionDto['type']) {
        'openSkill' => HomeAction.skill,
        'openTranslation' => HomeAction.translation,
        'openGenericTask' => HomeAction.genericTask,
        'none' => HomeAction.none,
        _ => throw const FormatException('Invalid entry action'),
      };
      final skill = optional(actionDto, 'skillId');
      if ((action == HomeAction.skill && skill == null) ||
          (action == HomeAction.translation &&
              skill != 'simultaneous_interpretation') ||
          (action == HomeAction.genericTask && skill != 'generic_task')) {
        throw const FormatException('Missing entry skill');
      }
      if (item['status'] == 'enabled' &&
          action == HomeAction.skill &&
          skill != 'apology_master' &&
          !skills.containsKey(skill)) {
        throw const FormatException('Missing entry opening');
      }
      return HomeCard(
        id: id,
        title: text(item, 'title', max: 6),
        subtitle: text(item, 'subtitle', max: 20),
        status: switch (item['status']) {
          'enabled' => HomeCardStatus.enabled,
          'comingSoon' => HomeCardStatus.comingSoon,
          _ => HomeCardStatus.disabled,
        },
        action: action,
        skillId: skill,
        opening: skills[skill] ?? '',
        selectedContactOpening: contactOpenings[skill],
        minimumVersion: optional(item, 'minClientVersion'),
        imageUrl: image(item['backgroundImage']),
        defaultVisible: item['defaultVisible'] is bool
            ? item['defaultVisible'] as bool
            : true,
      );
    });
    return HomeConfig(
      version,
      List.unmodifiable(slogans),
      List.unmodifiable(cards),
    );
  }

  String? image(Object? value) {
    if (value == null) return null;
    final dto = object(value);
    final url = text(dto, 'url');
    final asset = optional(dto, 'assetId');
    if (asset != null && !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(asset)) {
      throw const FormatException('Invalid image asset');
    }
    final direct = Uri.tryParse(url);
    if (direct?.scheme == 'https') {
      if (direct!.host.isEmpty ||
          direct.userInfo.isNotEmpty ||
          direct.hasFragment) {
        throw const FormatException('Invalid cloud image URL');
      }
      return direct.toString();
    }
    if (asset != null) {
      if (url != '/api/home-config/assets/$asset') {
        throw const FormatException('Invalid image asset');
      }
      return base
          .replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/')
          .resolve(url.substring(1))
          .toString();
    }
    throw const FormatException('Invalid image asset');
  }

  static List<T> ordered<T>(
    Object? value,
    T? Function(Map<String, dynamic>) map,
  ) {
    final result = <(int, T)>[];
    final ids = <String>{}, orders = <int>{};
    for (final raw in list(value)) {
      final item = object(raw);
      final mapped = map(item);
      if (mapped == null) continue;
      final order = item['sortOrder'];
      if (order is! int ||
          order <= 0 ||
          !orders.add(order) ||
          !ids.add(text(item, 'id'))) {
        throw const FormatException('Duplicate or invalid order');
      }
      result.add((order, mapped));
    }
    if (result.isEmpty) throw const FormatException('Empty config');
    result.sort((a, b) => a.$1.compareTo(b.$1));
    return result.map((e) => e.$2).toList();
  }

  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected object');
    }
    return value;
  }

  static List<dynamic> list(Object? value) {
    if (value is! List) throw const FormatException('Expected list');
    return value;
  }

  static String? optional(Map<String, dynamic> dto, String key) {
    final value = dto[key];
    if (value == null) return null;
    if (value is! String) throw const FormatException('Expected text');
    return value.trim().isEmpty ? null : value.trim();
  }

  static String text(Map<String, dynamic> dto, String key, {int? max}) {
    final value = optional(dto, key);
    if (value == null || (max != null && value.runes.length > max)) {
      throw const FormatException('Invalid text');
    }
    return value;
  }
}
