import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keep a scoped caller across a Navigator boundary, without registering a
/// second frame scheduler when that Navigator already inherits the container.
class RouteProviderScope extends StatelessWidget {
  const RouteProviderScope({
    super.key,
    required this.container,
    required this.child,
  });

  final ProviderContainer container;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      identical(ProviderScope.containerOf(context, listen: false), container)
      ? child
      : UncontrolledProviderScope(container: container, child: child);
}
