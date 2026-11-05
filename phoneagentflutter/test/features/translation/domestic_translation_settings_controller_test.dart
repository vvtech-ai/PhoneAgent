import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/controller/domestic_translation_settings_controller.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_provider_catalog.dart';

class Repository implements DomesticProviderRepository {
  bool fail = false;
  int switches = 0;
  Completer<DomesticProviderCatalog>? pending;
  DomesticProviderCatalog catalog(String active) => DomesticProviderCatalog(
    activeWireId: active,
    options: [
      DomesticProviderOption(
        wireId: 'QWEN_OMNI_PLUS',
        engine: 'QWEN',
        active: active == 'QWEN_OMNI_PLUS',
        configured: true,
        available: true,
        statusMessage: '',
      ),
      DomesticProviderOption(
        wireId: 'DOUBAO',
        engine: 'DOUBAO',
        active: active == 'DOUBAO',
        configured: true,
        available: true,
        statusMessage: '',
      ),
    ],
  );
  @override
  Future<DomesticProviderCatalog> load() async => catalog('QWEN_OMNI_PLUS');
  @override
  Future<DomesticProviderCatalog> select(String wireId) async {
    switches++;
    if (fail) {
      throw const FormatException();
    }
    return pending?.future ?? catalog(wireId);
  }
}

void main() {
  test(
    'server confirmed selection updates while failure and unknown choices preserve current',
    () async {
      final repo = Repository();
      final controller = DomesticTranslationSettingsController(
        repository: repo,
        isCurrent: () => true,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.ready, true);
      repo.fail = true;
      await controller.selectModel('DOUBAO');
      expect(controller.state.catalog!.activeEngine, 'QWEN');
      expect(controller.state.error, isNotEmpty);
      repo.fail = false;
      await controller.selectModel('DOUBAO');
      expect(controller.state.catalog!.activeEngine, 'DOUBAO');
      await controller.selectModel('unknown');
      expect(repo.switches, 2);
    },
  );
  test(
    'switch is single-flight and a late result cannot update a different account',
    () async {
      final repo = Repository();
      var current = true;
      final controller = DomesticTranslationSettingsController(
        repository: repo,
        isCurrent: () => current,
      );
      addTearDown(controller.dispose);
      await controller.load();
      repo.pending = Completer<DomesticProviderCatalog>();
      final switching = controller.selectModel('DOUBAO');
      await controller.selectModel('DOUBAO');
      expect(repo.switches, 1);
      current = false;
      repo.pending!.complete(repo.catalog('DOUBAO'));
      await switching;
      expect(controller.state.catalog!.activeEngine, 'QWEN');
    },
  );
}
