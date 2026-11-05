import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/task_voice_settings_providers.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import '../../support/synthetic_account_api.dart';

Map<String, Object?> catalog(String selected, {String model = 'task-tts'}) => {
  'modelId': model,
  'selectedVoice': selected,
  'defaultVoice': 'Andre',
  'voices': [
    {'voice': 'Maia', 'displayName': 'Maia', 'defaultVoice': false},
    {'voice': 'Andre', 'displayName': 'Andre', 'defaultVoice': true},
  ],
};

const shownMaia = TaskVoice('Maia', '', modelId: 'task-tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late SyntheticAccountApi wire;
  late ProviderContainer container;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storageChannel,
          (call) async => call.method == 'read' ? 'Maia' : null,
        );
    wire = SyntheticAccountApi()..data = catalog('Andre');
    container = ProviderContainer(
      overrides: [accountApiProvider.overrideWithValue(wire.api)],
    );
  });
  tearDown(() {
    container.dispose();
    wire.api.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('formal store reads and saves the SDK account selection', () async {
    final store = container.read(taskVoiceStoreProvider);
    expect(await store.read(), TaskVoice.andre);
    wire.beforeResponse = (request) async {
      if (request.method == 'PUT') wire.data = catalog('Maia');
    };
    await store.write(shownMaia);
    final saved = wire.requests.last;
    expect(saved.method, 'PUT');
    expect(saved.uri.path, '/api/account/settings/task-tts-voice');
    expect(saved.headers['Authorization'], 'Bearer synthetic');
    expect(saved.headers['X-Account-Id'], 'a');
    expect(
      saved.data is String ? jsonDecode(saved.data as String) : saved.data,
      {'modelId': 'task-tts', 'voiceCode': 'Maia'},
    );
    expect(await store.read(), TaskVoice.maia);
  });

  test(
    'Ethan from the live task voice contract is a valid current voice',
    () async {
      wire.data = {
        'modelId': 'task-tts',
        'selectedVoice': 'Ethan',
        'defaultVoice': 'Ethan',
        'voices': [
          {
            'voice': 'Ethan',
            'displayName': 'Ethan',
            'description': '合成男声',
            'defaultVoice': true,
          },
        ],
      };
      expect(
        (await container.read(taskVoiceStoreProvider).read()).speaker,
        'Ethan',
      );
    },
  );

  test(
    'server selection mismatch and changed model cannot report success',
    () async {
      final store = container.read(taskVoiceStoreProvider);
      await expectLater(
        store.write(shownMaia),
        throwsA(ApiFailure.invalidResponse),
      );
      wire.beforeResponse = (request) async {
        if (request.method == 'PUT') {
          wire.data = catalog('Maia', model: 'different-model');
        }
      };
      await expectLater(
        store.write(shownMaia),
        throwsA(ApiFailure.invalidResponse),
      );
    },
  );

  test('unavailable voice is rejected before PUT', () async {
    wire.data = {
      'modelId': 'task-tts',
      'selectedVoice': 'Andre',
      'defaultVoice': 'Andre',
      'voices': [
        {'voice': 'Andre', 'displayName': 'Andre', 'defaultVoice': true},
      ],
    };
    final store = container.read(taskVoiceStoreProvider);
    await expectLater(
      store.write(shownMaia),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(wire.requests.every((request) => request.method == 'GET'), isTrue);
  });

  test('a model changed after display is rejected before PUT', () async {
    final store =
        container.read(taskVoiceStoreProvider) as TaskVoiceCatalogStore;
    final shown = await store.load();
    final option = shown.voices.firstWhere((voice) => voice.speaker == 'Maia');
    wire.beforeResponse = (request) async {
      wire.data = catalog(
        request.method == 'PUT' ? 'Maia' : 'Andre',
        model: 'replacement-model',
      );
    };
    await expectLater(store.write(option), throwsA(ApiFailure.invalidResponse));
    expect(wire.requests.every((request) => request.method == 'GET'), isTrue);
  });

  test(
    'a device-only choice cannot bypass the displayed model guard',
    () async {
      await expectLater(
        container.read(taskVoiceStoreProvider).write(TaskVoice.maia),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(wire.requests, isEmpty);
    },
  );

  test(
    'a late previous-account load cannot change the new selection',
    () async {
      container.dispose();
      final epoch = StateProvider<int>((ref) => 1);
      final delayed = Completer<void>();
      wire.beforeResponse = (_) => delayed.future;
      final next = SyntheticAccountApi()..data = catalog('Maia');
      addTearDown(next.api.close);
      container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWith((ref) => ref.watch(epoch)),
          accountApiProvider.overrideWith(
            (ref) => ref.watch(loginEpochProvider) == 1 ? wire.api : next.api,
          ),
        ],
      );
      final loaded = Completer<void>();
      final hold = container.listen(taskVoiceControllerProvider, (_, state) {
        if (state.ready && !loaded.isCompleted) loaded.complete();
      });
      addTearDown(hold.close);
      await Future<void>.delayed(Duration.zero);
      container.read(epoch.notifier).state = 2;
      container.read(taskVoiceControllerProvider);
      await loaded.future.timeout(const Duration(seconds: 2));
      expect(container.read(taskVoiceControllerProvider).voice, TaskVoice.maia);
      wire.credentials = null;
      delayed.complete();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(taskVoiceControllerProvider).voice, TaskVoice.maia);
      expect(container.read(taskVoiceControllerProvider).ready, isTrue);
    },
  );
}
