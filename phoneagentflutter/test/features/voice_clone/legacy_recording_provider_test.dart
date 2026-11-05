import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/certified_recording_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import 'package:phone_agent/features/voice_clone/data/migrating_certified_recording_store.dart';
import 'package:phone_agent/features/voice_clone/domain/certified_recording_store.dart';
import 'clone_candidate_api_test.dart' show recordingFixture;

class _SessionStore implements SessionStore {
  AuthSession? value = const AuthSession(
    accountId: 'phone-synthetic',
    phone: '13800000000',
    accessToken: 'synthetic-token',
  );
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const oldChannel = MethodChannel('phone_agent/legacy_certified_recording');
  const newChannel = MethodChannel('phone_agent/certified_recording');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var legacyReads = 0;
  final slots = <String, Uint8List>{};
  setUp(() {
    legacyReads = 0;
    slots.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(oldChannel, (_) async {
      legacyReads++;
      final data = recordingFixture();
      return {
        'version': 1,
        'accountRef': 'phone-synthetic',
        'audio': data.audio,
        'audioSha256': data.audioSha256,
        'personFingerprint': data.personFingerprint,
        'scriptVersion': data.scriptVersion,
        'receipt': data.receipt,
      };
    });
    messenger.setMockMethodCallHandler(newChannel, (call) async {
      final args = call.arguments as Map;
      final slot = args['slot'] as String;
      if (call.method == 'read') return slots[slot];
      if (call.method == 'replace') slots[slot] = args['payload'] as Uint8List;
      if (call.method == 'clear') slots.remove(slot);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(oldChannel, null);
    messenger.setMockMethodCallHandler(newChannel, null);
  });
  Future<ProviderContainer> container({String environment = 'prod'}) async {
    final session = SessionController(_SessionStore());
    await session.restore();
    final result = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            environment: environment,
            apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
          ),
        ),
        sessionControllerProvider.overrideWith((ref) => session),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'unmodified production provider imports then deletion marker survives recreation',
    () async {
      final scope = await container();
      final repository = scope.read(certifiedRecordingRepositoryProvider);
      expect(repository.blobs, isA<MigratingCertifiedRecordingStore>());
      expect((await repository.read()).recording!.receipt, 'synthetic-receipt');
      await scope.read(prepareCertifiedRecordingClearProvider)()();
      scope.invalidate(certifiedRecordingRepositoryProvider);
      expect(
        (await scope.read(certifiedRecordingRepositoryProvider).read())
            .recording,
        isNull,
      );
      expect(legacyReads, 1);
      expect(slots.length, 1);
    },
  );
  test('dev and iOS providers bypass Android source entirely', () async {
    final dev = await container(environment: 'dev');
    final devRepo = dev.read(certifiedRecordingRepositoryProvider);
    expect(devRepo.blobs, isNot(isA<MigratingCertifiedRecordingStore>()));
    expect((await devRepo.read()).recording, isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = await container();
    final iosRepo = ios.read(certifiedRecordingRepositoryProvider);
    expect(iosRepo.blobs, isNot(isA<MigratingCertifiedRecordingStore>()));
    expect((await iosRepo.read()).recording, isNull);
    expect(legacyReads, 0);
  });
  test(
    'sign out invalidates retained recording repository before further IO',
    () async {
      final scope = await container();
      final repository = scope.read(certifiedRecordingRepositoryProvider);
      await scope.read(sessionControllerProvider.notifier).signOut();
      await expectLater(
        repository.read(),
        throwsA(RecordingStoreFailure.sessionChanged),
      );
      expect(legacyReads, 0);
      expect(slots, isEmpty);
    },
  );
}
