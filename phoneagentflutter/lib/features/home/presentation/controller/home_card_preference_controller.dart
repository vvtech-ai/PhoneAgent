import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/home_config.dart';
import '../../domain/home_card_preferences.dart';

class HomeCardPreferenceController extends ChangeNotifier {
  HomeCardPreferenceController(this.repository);
  final HomeCardPreferenceRepository repository;
  HomeCardPreferences preferences = const HomeCardPreferences();
  HomeCardPreferences _desired = const HomeCardPreferences();
  HomeCardPreferences? _failed;
  String notice = '';
  bool ready = false, readFailed = false, _closed = false;
  int _revision = 0;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    final revision = _revision;
    try {
      final stored = await repository.read();
      if (!_closed && revision == _revision) {
        preferences = _desired = stored;
        readFailed = false;
        notice = '';
      }
    } catch (_) {
      if (!_closed && revision == _revision) {
        readFailed = true;
        notice = '首页卡片偏好读取失败，可重试。';
      }
    }
    if (!_closed) {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> visibility(List<HomeCard> cards, String id, bool value) =>
      _save(HomeCardPreferencePolicy.visibility(cards, _desired, id, value));
  Future<void> move(List<HomeCard> cards, int from, int to) =>
      _save(HomeCardPreferencePolicy.move(cards, _desired, from, to));
  Future<void> reorder(List<HomeCard> cards, List<String> ids) {
    final available = HomeCardPreferencePolicy.ordered(
      cards,
      _desired,
    ).map((card) => card.id).toSet();
    if (ids.length != available.length ||
        ids.toSet().length != ids.length ||
        !available.containsAll(ids)) {
      return Future.value();
    }
    return _save(
      HomeCardPreferences(
        order: List.unmodifiable(ids),
        visibility: _desired.visibility,
      ),
    );
  }

  Future<void> reset() => _save(const HomeCardPreferences());
  Future<void> retry() => readFailed
      ? load()
      : _failed == null
      ? Future.value()
      : _save(_failed!);
  Future<void> _save(HomeCardPreferences next) {
    if (_closed) return Future.value();
    final revision = ++_revision;
    _desired = next;
    _failed = null;
    notice = '';
    notifyListeners();
    return _writes = _writes.then((_) async {
      if (_closed) return;
      try {
        await repository.save(next);
        if (_closed) return;
        preferences = next;
        if (revision == _revision) {
          readFailed = false;
          notice = '';
        }
      } catch (_) {
        if (!_closed && revision == _revision) {
          _failed = next;
          notice = '设置未保存，请重试';
        }
      }
      if (!_closed) {
        if (revision == _revision) _desired = preferences;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
