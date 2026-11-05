import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/apology_voice_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/app/confirmation_billing_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/apology/domain/apology_voice.dart';
import 'package:phone_agent/features/apology/presentation/controller/apology_conversation_binding.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/calls/domain/call_admission.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import 'package:phone_agent/features/calls/domain/confirmation_billing.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import '../../../tool/previews/shell_conversation_fakes.dart';
import '../../support/call_admission_fixture.dart';
import '../../support/local_storage_channel_fake.dart';
import '../../support/synthetic_account_api.dart';

class _Models implements CallModelRepository {
  _Models(this.active);
  String active;
  final unavailable = <String>{};
  @override
  Future<CallModelCatalog> load() async => CallModelCatalog(active, [
    for (final (id, title) in [('seed', 'Seeduplex'), ('qwen', 'QwenOmniPlus')])
      CallModel(
        id: id,
        name: title,
        description: '',
        available: !unavailable.contains(id),
        active: active == id,
      ),
  ]);
  @override
  Future<CallModelCatalog> select(String provider) async {
    active = provider;
    return load();
  }

  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async =>
      const CallVoiceCatalog('', '', []);
  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) =>
      loadVoices(provider);
}

class _Wallet implements PointsWalletRepository {
  int balance = 105, reads = 0;
  @override
  Future<PointsAccount> account() async {
    reads++;
    return PointsAccount(
      totalBalance: balance,
      availableBalance: balance,
      heldBalance: 0,
      updatedAt: 'synthetic',
    );
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      const PointsLedgerPage(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
      );
}

class _Voices implements ApologyVoicePort {
  Completer<List<ApologyVoice>>? pending;
  @override
  Future<List<ApologyVoice>> voices() async =>
      pending?.future ??
      const [
        ApologyVoice('seed', 'Seeduplex', 'asset-seed', active: true),
        ApologyVoice('qwen', 'QwenOmniPlus', 'asset-qwen', active: true),
      ];
  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {}
}

class _PinnedHistory extends OfflineHistory {
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final prior = await super.restore(sessionId);
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: 'Synthetic apology',
        status: 'ACTIVE',
        pinnedSkillId: 'apology_master',
        taskCallModelId: 'qwen',
      ),
      ledger: prior.ledger,
    );
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Fixture {
  _Fixture(String global, {bool restore = false, bool apology = true})
    : models = _Models(global),
      entry = ConversationEntry(
        sessionId: 'task',
        skillId: apology ? 'apology_master' : 'restaurant',
        restore: restore,
      ) {
    modelController = CallModelController(models);
    walletController = PointsWalletController(wallet);
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(OfflineSessionStore()),
        accountApiProvider.overrideWithValue(wire.api),
        callModelControllerProvider.overrideWith((ref) => modelController),
        pointsWalletControllerProvider.overrideWith((ref) => walletController),
        apologyVoicePortProvider.overrideWithValue(voices),
      ],
    );
    binding = Provider<void>((ref) => bindApologyModelChanges(ref, controller));
    dependencies = Provider((ref) => apologyVoiceDependencies(ref));
  }
  final _Models models;
  final ConversationEntry entry;
  final wallet = _Wallet(), voices = _Voices(), wire = SyntheticAccountApi();
  late final ProviderContainer container;
  late final CallModelController modelController;
  late final PointsWalletController walletController;
  late final Provider<void> binding;
  late final Provider<ApologyVoiceDependencies> dependencies;
  late final ConversationController controller;
  late final CallAdmissionService admission;
  late final ProviderSubscription<CallAdmissionService> keep;
  Future<void> open() async {
    await container.read(sessionControllerProvider.notifier).restore();
    await modelController.load();
    await walletController.refreshBalance();
    keep = container.listen(callAdmissionProvider(entry.sessionId), (_, __) {});
    admission = keep.read();
    controller = ConversationController(
      entry: entry,
      accountId: 'synthetic',
      gateway: OfflineAgent(),
      history: _PinnedHistory(),
      apologyVoice: container.read(dependencies),
    );
    container.read(binding);
    if (entry.restore) await controller.restore();
    await _flush();
  }

  Future<void> choose(String model) async {
    final voice = controller.apology!.voice;
    voice.restore(models.active);
    voice.modelChanged(model);
    await _flush();
    expect(voice.blocked, isFalse);
  }

  Future<ConfirmationBillingSnapshot> quote(String alias) => container.read(
    confirmationBillingProvider(
      ConfirmationBillingRequest(entry.sessionId, [alias]),
    ).future,
  );
  Future<CallAdmissionDecision?> evaluate() => admission.evaluate(
    callRequest(session: entry.sessionId),
    priorRequests: const [],
    isCurrent: () => controller.isOpen,
  );
  void close() {
    keep.close();
    controller.dispose();
    container.dispose();
    wire.api.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    installLocalStorageChannelFake();
  });

  test(
    'task Qwen quote and admission use 100 while global Seeduplex stays 110',
    () async {
      final f = _Fixture('seed');
      await f.open();
      addTearDown(f.close);
      await f.choose('qwen');
      final quote = await f.quote('confirmation');
      expect(quote.modelTitle, 'QwenOmniPlus');
      expect(quote.firstMinute, 100);
      final decision = await f.evaluate();
      expect(decision?.kind, CallAdmissionKind.allow);
      expect(decision?.requiredPoints, 100);
      final confirmed = f.controller.apology!.command(
        callRequest(session: 'task').command('synthetic', 'confirm', 'trace'),
      );
      expect(confirmed.callVoiceSelection?['modelId'], 'qwen');
      expect(
        confirmed.actionPayload?['callVoiceSelection'],
        confirmed.callVoiceSelection,
      );
      expect(f.modelController.state.catalog?.current?.id, 'seed');
    },
  );

  test(
    'task Seeduplex blocks at 105 even while global Qwen would allow',
    () async {
      final f = _Fixture('qwen');
      await f.open();
      addTearDown(f.close);
      await f.choose('seed');
      expect((await f.quote('confirmation')).firstMinute, 110);
      final decision = await f.evaluate();
      expect(decision?.kind, CallAdmissionKind.firstInsufficient);
      expect(decision?.requiredPoints, 110);
      expect(f.modelController.state.catalog?.current?.id, 'qwen');
    },
  );

  test(
    'restored pinned task model is read after binding and before quote',
    () async {
      final f = _Fixture('seed', restore: true);
      await f.open();
      addTearDown(f.close);
      expect(f.controller.apology!.voice.modelId, 'qwen');
      expect((await f.quote('restored')).firstMinute, 100);
      expect((await f.evaluate())?.kind, CallAdmissionKind.allow);
    },
  );

  test(
    'saved quote stays fixed while new quote and refreshed admission follow task',
    () async {
      final f = _Fixture('seed');
      await f.open();
      addTearDown(f.close);
      await f.choose('qwen');
      expect((await f.quote('old')).firstMinute, 100);
      f.controller.apology!.voice.modelChanged('seed');
      await _flush();
      f.container.invalidate(
        confirmationBillingProvider(
          ConfirmationBillingRequest('task', ['old']),
        ),
      );
      expect((await f.quote('old')).firstMinute, 100);
      expect((await f.quote('new')).firstMinute, 110);
      f.wallet.balance = 115;
      final reads = f.wallet.reads;
      final decision = await f.evaluate();
      expect(decision?.kind, CallAdmissionKind.allow);
      expect(decision?.balance, 115);
      expect(f.wallet.reads, reads + 1);
    },
  );

  test('pending switch and stale voice result cannot admit a call', () async {
    final f = _Fixture('qwen');
    await f.open();
    addTearDown(f.close);
    await f.choose('seed');
    final stale = Completer<List<ApologyVoice>>();
    f.voices.pending = stale;
    f.controller.apology!.voice.modelChanged('qwen');
    expect(f.admission.modelReady, isFalse);
    await expectLater(f.evaluate(), throwsStateError);
    final current = Completer<List<ApologyVoice>>();
    f.voices.pending = current;
    f.controller.apology!.voice.modelChanged('seed');
    stale.complete(const [
      ApologyVoice('qwen', 'QwenOmniPlus', 'stale', active: true),
    ]);
    await _flush();
    expect(f.admission.modelReady, isFalse);
    current.complete(const [
      ApologyVoice('seed', 'Seeduplex', 'current', active: true),
    ]);
    await _flush();
    expect(f.admission.modelReady, isTrue);
    expect((await f.evaluate())?.requiredPoints, 110);
  });

  test(
    'unavailable task model cannot be replaced by global admission',
    () async {
      final f = _Fixture('seed');
      await f.open();
      addTearDown(f.close);
      await f.choose('qwen');
      f.voices.pending = Completer<List<ApologyVoice>>();
      f.models.unavailable.add('qwen');
      await f.modelController.load();
      expect(f.admission.modelReady, isFalse);
      await expectLater(f.evaluate(), throwsStateError);
      f.voices.pending!.complete(const []);
      await _flush();
    },
  );

  test('ordinary task still quotes and admits with global selection', () async {
    final f = _Fixture('seed', apology: false);
    await f.open();
    addTearDown(f.close);
    expect((await f.quote('ordinary')).firstMinute, 110);
    expect((await f.evaluate())?.kind, CallAdmissionKind.firstInsufficient);
  });
}
