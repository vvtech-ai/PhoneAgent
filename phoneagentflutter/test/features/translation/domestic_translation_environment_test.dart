import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/features/translation/domain/translation_call_environment.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_environment.dart';

class _Network implements NetworkAvailabilitySource, NetworkAvailabilityEvents {
  final controller = StreamController<NetworkAvailability>.broadcast(
    sync: true,
  );
  final readGate = Completer<NetworkAvailability>();
  @override
  Future<NetworkAvailability> read() => readGate.future;
  @override
  Stream<NetworkAvailability> watch() => controller.stream;
}

void main() {
  test(
    'unknown remains pending until protocol evidence; offline is never overwritten by handshake',
    () async {
      final network = _Network();
      final states = <TranslationCallEnvironment>[];
      final owner = DomesticTranslationEnvironment(
        network: network,
        isCurrent: () => true,
        onChanged: states.add,
      );
      owner.start();
      expect(states.last.network, TranslationEnvironmentState.pending);
      expect(states.last.model, TranslationEnvironmentState.pending);
      owner.preparingModels();
      owner.modelReady();
      expect(states.last.model, TranslationEnvironmentState.available);
      expect(states.last.sip, TranslationEnvironmentState.pending);
      expect(states.last.network, TranslationEnvironmentState.available);
      network.controller.add(NetworkAvailability.unavailable);
      owner.preparingSip();
      owner.sipReady();
      expect(states.last.network, TranslationEnvironmentState.unavailable);
      expect(states.last.sip, TranslationEnvironmentState.available);
      owner.modelFailed();
      expect(states.last.model, TranslationEnvironmentState.unavailable);
      expect(states.last.sip, TranslationEnvironmentState.available);
      expect(
        states.map((e) => e.version),
        orderedEquals(List.generate(states.length, (i) => i + 1)),
      );
      await owner.stop();
      network.readGate.complete(NetworkAvailability.available);
      await network.controller.close();
    },
  );
  test(
    'new network events outrank old read; stop and logout reject late updates',
    () async {
      final network = _Network();
      final states = <TranslationCallEnvironment>[];
      var current = true;
      final owner = DomesticTranslationEnvironment(
        network: network,
        isCurrent: () => current,
        onChanged: states.add,
      );
      owner.start();
      network.controller.add(NetworkAvailability.available);
      network.readGate.complete(NetworkAvailability.unavailable);
      await Future<void>.delayed(Duration.zero);
      expect(states.last.network, TranslationEnvironmentState.available);
      final count = states.length;
      current = false;
      network.controller.add(NetworkAvailability.unavailable);
      owner.modelReady();
      expect(states.length, count);
      current = true;
      await owner.stop();
      network.controller.add(NetworkAvailability.unavailable);
      owner.sipFailed();
      expect(states.length, count);
      expect(network.controller.hasListener, false);
      await network.controller.close();
    },
  );
}
