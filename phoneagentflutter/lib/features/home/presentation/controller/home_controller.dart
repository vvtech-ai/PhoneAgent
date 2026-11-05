import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/home_config.dart';
import '../../domain/home_defaults.dart';

class HomeState {
  const HomeState({
    this.config = builtinHome,
    this.slogan,
    this.loading = false,
    this.notice = '',
  });
  final HomeConfig config;
  final HomeSlogan? slogan;
  final bool loading;
  final String notice;
}

class HomeController extends StateNotifier<HomeState> {
  HomeController(this._repository) : super(const HomeState());
  final HomeRepository _repository;
  HomeSlogan? _sessionSlogan;
  bool _rotatingSlogan = false;

  Future<void> refresh() async {
    if (!mounted || state.loading) return;
    state = HomeState(
      config: state.config,
      slogan: _sessionSlogan,
      loading: true,
    );
    try {
      final config = await _repository.load();
      if (!mounted) return;
      state = HomeState(
        config: config,
        slogan: _sessionSlogan ?? config.slogans.first,
        notice:
            _repository is HomeRepositoryStatus &&
                (_repository as HomeRepositoryStatus).loadFailed
            ? '首页配置加载失败，已显示可用入口，请重试'
            : '',
      );
      if (_sessionSlogan == null && !_rotatingSlogan) {
        _rotatingSlogan = true;
        unawaited(_rotateSlogan(config));
      }
    } catch (_) {
      if (mounted) {
        state = HomeState(
          config: state.config,
          slogan: _sessionSlogan,
          notice: '首页配置加载失败，请重试',
        );
      }
    }
  }

  Future<void> _rotateSlogan(HomeConfig config) async {
    HomeSlogan slogan;
    try {
      slogan = await _repository.nextSlogan(config);
    } catch (_) {
      slogan = config.slogans.first;
    }
    if (!mounted) return;
    _sessionSlogan = slogan;
    _rotatingSlogan = false;
    state = HomeState(
      config: state.config,
      slogan: slogan,
      loading: state.loading,
      notice: state.notice,
    );
  }
}
