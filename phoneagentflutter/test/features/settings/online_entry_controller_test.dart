import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/presentation/controller/online_entry_controller.dart';

class SampleSource implements NetworkAvailabilitySource {
  NetworkAvailability value = NetworkAvailability.available;
  Completer<NetworkAvailability>? pending;
  bool fail = false;
  int reads = 0;
  @override
  Future<NetworkAvailability> read() {
    reads++;
    if (fail) throw StateError('synthetic');
    return pending?.future ?? Future.value(value);
  }
}

void main() {
  for (final entry in {
    NetworkAvailability.available: OnlineEntryDecision.available,
    NetworkAvailability.unavailable: OnlineEntryDecision.offline,
    NetworkAvailability.unknown: OnlineEntryDecision.unknown,
  }.entries) {
    test('preserves OS evidence ${entry.key}', () async {
      final source = SampleSource()..value = entry.key;
      final controller = OnlineEntryController(source, () => false);
      addTearDown(controller.close);
      final attempt = controller.begin()!;
      expect(await attempt.check(), entry.value);
      expect(source.reads, 1);
      expect(
        entry.value.canAttempt,
        entry.key != NetworkAvailability.unavailable,
      );
    });
  }

  test(
    'simulation offline skips OS and changing to normal samples again',
    () async {
      var simulated = true;
      final source = SampleSource()..value = NetworkAvailability.unavailable;
      final controller = OnlineEntryController(source, () => simulated);
      addTearDown(controller.close);
      final attempt = controller.begin()!;
      expect(await attempt.check(), OnlineEntryDecision.simulatedOffline);
      expect(source.reads, 0);
      simulated = false;
      expect(await attempt.check(), OnlineEntryDecision.offline);
      expect(source.reads, 1);
    },
  );

  test('read failure is unknown not positive or a permanent lock', () async {
    final source = SampleSource()..fail = true;
    final controller = OnlineEntryController(source, () => false);
    addTearDown(controller.close);
    expect(await controller.begin()!.check(), OnlineEntryDecision.unknown);
  });

  test(
    'bounded wait becomes unknown; late response does not become new decision',
    () async {
      final source = SampleSource()..pending = Completer<NetworkAvailability>();
      final controller = OnlineEntryController(
        source,
        () => false,
        timeout: const Duration(milliseconds: 5),
      );
      addTearDown(controller.close);
      final attempt = controller.begin()!;
      final checking = attempt.check();
      expect(await checking, OnlineEntryDecision.unknown);
      source.pending!.complete(NetworkAvailability.unavailable);
      expect(await checking, OnlineEntryDecision.unknown);
    },
  );

  test('one entry and one read until lease closes; retry re-reads', () async {
    final source = SampleSource()..pending = Completer<NetworkAvailability>();
    final controller = OnlineEntryController(source, () => false);
    addTearDown(controller.close);
    final attempt = controller.begin()!;
    expect(controller.begin(), isNull);
    final first = attempt.check();
    expect(identical(first, attempt.check()), isTrue);
    expect(source.reads, 1);
    source.pending!.complete(NetworkAvailability.unavailable);
    expect(await first, OnlineEntryDecision.offline);
    source.pending = null;
    expect(await attempt.check(), OnlineEntryDecision.available);
    expect(source.reads, 2);
    expect(controller.begin(), isNull);
    attempt.close();
    expect(controller.begin(), isNotNull);
    expect(await attempt.check(), OnlineEntryDecision.cancelled);
  });

  test(
    'closed attempt cannot deliver late result or close a newer lease',
    () async {
      final source = SampleSource()..pending = Completer<NetworkAvailability>();
      final controller = OnlineEntryController(source, () => false);
      addTearDown(controller.close);
      final old = controller.begin()!;
      final checking = old.check();
      old.close();
      final next = controller.begin()!;
      source.pending!.complete(NetworkAvailability.available);
      expect(await checking, OnlineEntryDecision.cancelled);
      old.close();
      expect(controller.begin(), isNull);
      next.close();
      expect(controller.begin(), isNotNull);
    },
  );

  test('controller disposal invalidates pending and cannot reopen', () async {
    final source = SampleSource()..pending = Completer<NetworkAvailability>();
    final controller = OnlineEntryController(source, () => false);
    final checking = controller.begin()!.check();
    controller.close();
    source.pending!.complete(NetworkAvailability.available);
    expect(await checking, OnlineEntryDecision.cancelled);
    expect(controller.begin(), isNull);
  });

  test('simulation changed during OS read takes precedence', () async {
    var simulated = false;
    final source = SampleSource()..pending = Completer<NetworkAvailability>();
    final controller = OnlineEntryController(source, () => simulated);
    addTearDown(controller.close);
    final checking = controller.begin()!.check();
    simulated = true;
    source.pending!.complete(NetworkAvailability.available);
    expect(await checking, OnlineEntryDecision.simulatedOffline);
  });
}
