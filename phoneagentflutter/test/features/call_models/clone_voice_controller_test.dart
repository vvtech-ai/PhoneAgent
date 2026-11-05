import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';

const model = 'QWEN_OMNI_PLUS';
const voice = CallVoice('Andre', 'Andre', '', true);
const current = CloneVoiceSnapshot(
  modelId: model,
  available: true,
  currentStatus: 'READY',
  currentHasAsset: true,
);
const candidate = CloneVoiceSnapshot(
  modelId: model,
  available: true,
  currentStatus: 'NOT_CREATED',
  currentHasAsset: false,
  candidateStatus: 'READY',
  candidateBillingStatus: 'CHARGED',
);
const callModel = CallModel(
  id: model,
  name: 'Qwen',
  description: '',
  available: true,
  active: true,
);

void main() {
  late _Models models;
  late _Clones clones;
  late CallModelController controller;
  setUp(() {
    models = _Models();
    clones = _Clones(models);
    controller = CallModelController(models, cloneRepository: clones);
  });
  tearDown(() => controller.dispose());
  Future<void> load() async {
    await controller.load();
    await controller.loadVoices(model);
  }

  test(
    'clone and system catalogs load together; unsupported model skips clone GET',
    () async {
      await load();
      expect(controller.state.clone!.currentReady, isTrue);
      expect(controller.state.voices!.selectionMode, 'AI');
      await controller.loadVoices('DOUBAO');
      expect(controller.state.clone, isNull);
      expect(controller.state.cloneLoading, isFalse);
      expect(clones.loads, 1);
    },
  );
  test(
    'select current clone then switch back to AI without candidate POST',
    () async {
      await load();
      await controller.selectClone();
      expect(clones.selects, 1);
      expect(clones.confirms, 0);
      expect(controller.state.voices!.selectionMode, 'CLONE');
      await controller.selectClone();
      expect(clones.selects, 1);
      await controller.selectVoice(voice);
      expect(models.selects, 1);
      expect(controller.state.voices!.selectionMode, 'AI');
    },
  );
  test(
    'charged ready candidate is confirmed once and no CLONE PUT follows',
    () async {
      clones.snapshot = candidate;
      await load();
      await controller.selectClone();
      expect(clones.confirms, 1);
      expect(clones.selects, 0);
      expect(controller.state.voices!.selectionMode, 'CLONE');
      expect(controller.state.clone!.candidateReady, isFalse);
    },
  );
  test('unpaid candidate cannot be used', () async {
    clones.snapshot = const CloneVoiceSnapshot(
      modelId: model,
      available: true,
      currentStatus: 'NOT_CREATED',
      currentHasAsset: false,
      candidateStatus: 'READY',
      candidateBillingStatus: 'PENDING',
    );
    await load();
    await controller.selectClone();
    expect(clones.confirms + clones.selects, 0);
  });
  test(
    'one in-flight clone write blocks AI, model switch and duplicate selection',
    () async {
      await load();
      clones.writeGate = Completer<void>();
      final pending = controller.selectClone();
      await controller.selectClone();
      await controller.selectVoice(voice);
      expect(await controller.select(callModel), isFalse);
      expect(clones.selects, 1);
      expect(models.selects, 0);
      clones.writeGate!.complete();
      await pending;
      expect(controller.state.voiceSaving, isFalse);
    },
  );
  test(
    'confirmed write and failed read only retry reads, never confirmation',
    () async {
      clones.snapshot = candidate;
      await load();
      clones.afterWrite = () => models.failRead = true;
      await controller.selectClone();
      expect(controller.state.cloneNeedsRefresh, isTrue);
      expect(controller.state.voiceError, isNotEmpty);
      await controller.selectClone();
      await controller.selectVoice(voice);
      expect(clones.confirms, 1);
      expect(models.selects, 0);
      models.failRead = false;
      await controller.loadVoices(model);
      expect(controller.state.cloneNeedsRefresh, isFalse);
      expect(controller.state.voices!.selectionMode, 'CLONE');
      expect(clones.confirms, 1);
    },
  );
  test('ambiguous write must reconcile before another selection', () async {
    await load();
    clones.failWrite = true;
    await controller.selectClone();
    await controller.selectClone();
    expect(clones.selects, 1);
    expect(controller.state.cloneNeedsRefresh, isTrue);
    expect(controller.state.voices!.selectionMode, 'AI');
    expect(controller.state.cloneError, isNotEmpty);
    clones.failWrite = false;
    await controller.loadVoices(model);
    await controller.selectClone();
    expect(controller.state.voices!.selectionMode, 'CLONE');
  });
  test(
    'failed system write requires read sync before another selection',
    () async {
      await load();
      await controller.selectClone();
      models.failWrite = true;
      await controller.selectVoice(voice);
      expect(controller.state.voiceError, contains('刷新'));
      expect(controller.state.cloneNeedsRefresh, isTrue);
      await controller.selectVoice(voice);
      await controller.selectClone();
      expect(models.selects, 1);
      expect(clones.selects, 1);
      models.failWrite = false;
      await controller.loadVoices(model);
      expect(controller.state.cloneNeedsRefresh, isFalse);
      await controller.selectVoice(voice);
      expect(controller.state.voices!.selectionMode, 'AI');
    },
  );
  test('clone GET failure is independent from usable system voices', () async {
    clones.failRead = true;
    await load();
    expect(controller.state.cloneError, isNotEmpty);
    expect(controller.state.voices!.voices, isNotEmpty);
    await controller.selectVoice(voice);
    expect(models.selects, 0); // already selected AI, no redundant write.
    await controller.selectClone();
    expect(clones.selects, 0);
  });
  test(
    'late previous-model clone snapshot cannot overwrite new model',
    () async {
      clones.readGate = Completer<CloneVoiceSnapshot>();
      final pending = controller.loadVoices(model);
      await controller.loadVoices('DOUBAO');
      clones.readGate!.complete(current);
      await pending;
      expect(controller.state.voiceProvider, 'DOUBAO');
      expect(controller.state.clone, isNull);
    },
  );
  test('dispose during clone write ignores late results', () async {
    await load();
    clones.writeGate = Completer<void>();
    final pending = controller.selectClone();
    controller.dispose();
    // Replace for tearDown; the disposed instance must not publish or refresh.
    controller = CallModelController(models, cloneRepository: clones);
    clones.writeGate!.complete();
    await pending;
    expect(clones.loads, 1);
    expect(controller.state.voices, isNull);
  });
}

class _Models implements CallModelRepository {
  String mode = 'AI';
  bool failRead = false, failWrite = false;
  int selects = 0;
  CallVoiceCatalog get voices => CallVoiceCatalog('Andre', mode, [voice]);
  @override
  Future<CallModelCatalog> load() async =>
      const CallModelCatalog(model, [callModel]);
  @override
  Future<CallModelCatalog> select(String provider) async =>
      CallModelCatalog(provider, []);
  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async {
    if (failRead) throw StateError('synthetic');
    return voices;
  }

  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) async {
    selects++;
    if (failWrite) throw StateError('synthetic');
    mode = 'AI';
    return voices;
  }
}

class _Clones implements CloneVoiceRepository {
  _Clones(this.models);
  final _Models models;
  CloneVoiceSnapshot snapshot = current;
  bool failRead = false, failWrite = false;
  int loads = 0, selects = 0, confirms = 0;
  Completer<CloneVoiceSnapshot>? readGate;
  Completer<void>? writeGate;
  void Function()? afterWrite;
  @override
  Future<CloneVoiceSnapshot> load(String provider) async {
    loads++;
    if (failRead) throw StateError('synthetic');
    return readGate == null ? snapshot : await readGate!.future;
  }

  Future<void> _write() async {
    if (writeGate != null) await writeGate!.future;
    if (failWrite) throw StateError('synthetic');
    models.mode = 'CLONE';
    snapshot = current;
    afterWrite?.call();
  }

  @override
  Future<CallVoiceCatalog> selectConfirmed(String provider) async {
    selects++;
    await _write();
    return models.voices;
  }

  @override
  Future<void> confirmCandidate(String provider) async {
    confirms++;
    await _write();
  }
}
