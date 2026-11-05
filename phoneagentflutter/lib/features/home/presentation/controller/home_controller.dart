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
  HomeController(HomeRepository repository)
    : _repository = repository,
      super(
        HomeState(
          config: repository is HomePublishedSnapshots
              ? (repository as HomePublishedSnapshots).initialSnapshot
              : builtinHome,
        ),
      ) {
    if (repository is HomePublishedSnapshots) {
      _published = (repository as HomePublishedSnapshots).publishedSnapshots
          .listen((config) {
            if (!mounted) return;
            _publishedRevision++;
            _publish(config);
          });
    }
  }
  final HomeRepository _repository;
  StreamSubscription<HomeConfig>? _published;
  int _publishedRevision = 0;
  HomeSlogan? _sessionSlogan;
  bool _rotatingSlogan = false;

  Future<void> refresh() async {
    if (!mounted || state.loading) return;
    final revision = _publishedRevision;
    state = HomeState(
      config: state.config,
      slogan: _sessionSlogan,
      loading: true,
    );
    try {
      final config = await _repository.load();
      if (!mounted || revision != _publishedRevision) return;
      _publish(config);
    } catch (_) {
      if (mounted && revision == _publishedRevision) {
        state = HomeState(
          config: state.config,
          slogan: _sessionSlogan,
          notice: '首页配置加载失败，请重试',
        );
      }
    }
  }

  void _publish(HomeConfig config) {
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

  @override
  void dispose() {
    unawaited(_published?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
