import 'package:flutter/widgets.dart';

/// The visible business page is unchanged by menus and other PopupRoutes.
class PageRouteVisibilityObserver extends NavigatorObserver
    with ChangeNotifier {
  final _routes = <Route<dynamic>>[];
  PageRoute<dynamic>? _currentPage;
  bool _disposed = false;
  PageRoute<dynamic>? get currentPage => _currentPage;

  void _update() {
    final page = _routes.reversed.whereType<PageRoute<dynamic>>().firstOrNull;
    if (identical(page, _currentPage)) return;
    _currentPage = page;
    if (!_disposed) notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null) return;
    final index = _routes.indexOf(oldRoute);
    if (index < 0) return;
    if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
    _update();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class PageRouteVisibilityScope extends InheritedWidget {
  const PageRouteVisibilityScope({
    super.key,
    required this.observer,
    required super.child,
  });
  final PageRouteVisibilityObserver observer;
  static PageRouteVisibilityObserver of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PageRouteVisibilityScope>();
    assert(
      scope != null,
      'PageRouteVisibilityScope is required for task feedback.',
    );
    return scope!.observer;
  }

  @override
  bool updateShouldNotify(PageRouteVisibilityScope oldWidget) =>
      observer != oldWidget.observer;
}
