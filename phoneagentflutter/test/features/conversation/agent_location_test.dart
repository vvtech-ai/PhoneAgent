import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/agent_location_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/domain/context/agent_location.dart';
import 'package:phone_agent/features/conversation/presentation/controller/agent_location_controller.dart';

class LocationSource implements AgentLocationSource {
  AgentLocation? value;
  Completer<AgentLocation?>? pending;
  bool fails = false;
  int reads = 0, cancels = 0;
  @override
  Future<AgentLocation?> read() async {
    reads++;
    if (fails) throw StateError('Synthetic failure');
    return pending == null ? value : await pending!.future;
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  test('strict coordinate evidence and display fallback', () {
    for (final point in [
      [double.nan, 10.0],
      [91.0, 0.0],
      [1.0, 181.0],
      [0.0, 0.0],
    ]) {
      expect(() => AgentLocation(point[0], point[1]), throwsFormatException);
    }
    final value = AgentLocation(22.5, 114, address: '  合成街道  ');
    expect(value.display, '合成街道');
    expect(value.toContext(), {'lat': 22.5, 'lng': 114.0});
    expect(AgentLocation(22.5, 114).display, '22.5000, 114.0000');
  });
  test('no eager read; no sample does not manufacture coordinates', () async {
    final source = LocationSource();
    final controller = AgentLocationController(source);
    addTearDown(controller.dispose);
    expect(source.reads, 0);
    expect(await controller.context(), isEmpty);
    expect(await controller.context(), isEmpty);
    expect(source.reads, 2);
  });
  test(
    'TTL refresh and failure retain previous same-account snapshot',
    () async {
      final source = LocationSource()..value = AgentLocation(1, 2);
      var elapsed = Duration.zero;
      final controller = AgentLocationController(
        source,
        elapsed: () => elapsed,
      );
      addTearDown(controller.dispose);
      expect(await controller.context(), {'lat': 1.0, 'lng': 2.0});
      source.value = AgentLocation(3, 4);
      elapsed = const Duration(seconds: 119);
      expect(await controller.context(), {'lat': 1.0, 'lng': 2.0});
      expect(source.reads, 1);
      elapsed = const Duration(minutes: 2);
      expect(await controller.context(), {'lat': 3.0, 'lng': 4.0});
      elapsed = const Duration(minutes: 5);
      source.fails = true;
      expect(await controller.context(), {'lat': 3.0, 'lng': 4.0});
      source.fails = false;
      source.value = null;
      expect(await controller.context(), {'lat': 3.0, 'lng': 4.0});
      expect(source.reads, 4);
    },
  );
  test('single-flight and timeout ignore late sample', () async {
    final source = LocationSource()..pending = Completer<AgentLocation?>();
    final controller = AgentLocationController(
      source,
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(controller.dispose);
    final first = controller.context();
    expect(identical(first, controller.context()), true);
    expect(await first, isEmpty);
    expect(source.reads, 1);
    expect(source.cancels, 1);
    source.pending!.complete(AgentLocation(1, 2));
    await Future<void>.delayed(Duration.zero);
    source.pending = null;
    expect(await controller.context(), isEmpty);
  });
  for (final fails in [false, true]) {
    test(
      'expired same-account position is not sent after failed refresh $fails',
      () async {
        final source = LocationSource()..value = AgentLocation(1, 2);
        var elapsed = Duration.zero;
        final controller = AgentLocationController(
          source,
          elapsed: () => elapsed,
        );
        addTearDown(controller.dispose);
        expect(await controller.context(), {'lat': 1.0, 'lng': 2.0});
        elapsed = const Duration(minutes: 4);
        source.value = null;
        source.fails = fails;
        expect(await controller.context(), {'lat': 1.0, 'lng': 2.0});
        elapsed = const Duration(minutes: 5);
        expect(await controller.context(), isEmpty);
        expect(controller.state?.lat, 1);
        source.fails = false;
        source.value = AgentLocation(3, 4);
        expect(await controller.context(), {'lat': 3.0, 'lng': 4.0});
      },
    );
  }
  test(
    'dispose cancels and prevents late context from crossing account',
    () async {
      final source = LocationSource()..pending = Completer<AgentLocation?>();
      final controller = AgentLocationController(source);
      final result = controller.context();
      controller.dispose();
      source.pending!.complete(AgentLocation(1, 2));
      expect(await result, isEmpty);
      expect(await controller.context(), isEmpty);
      expect(source.cancels, 1);
    },
  );
  test('provider login replacement clears account snapshot', () async {
    var epoch = 1;
    final sources = <LocationSource>[];
    final container = ProviderContainer(
      overrides: [
        loginEpochProvider.overrideWith((_) => epoch),
        agentLocationSourceProvider.overrideWith((ref) {
          ref.watch(loginEpochProvider);
          final source = LocationSource()
            ..value = AgentLocation(epoch.toDouble(), 2);
          sources.add(source);
          return source;
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(agentLocationProvider, (_, __) {});
    addTearDown(sub.close);
    await container.read(agentLocationProvider.notifier).context();
    expect(container.read(agentLocationProvider)?.lat, 1);
    epoch = 2;
    container.invalidate(loginEpochProvider);
    expect(container.read(agentLocationProvider), isNull);
    await container.read(agentLocationProvider.notifier).context();
    expect(container.read(agentLocationProvider)?.lat, 2);
    expect(sources.first.cancels, 1);
  });
}
