import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/call_monitor_providers.dart';
import 'package:phone_agent/app/call_session_providers.dart';
import 'package:phone_agent/app/task_voice_transport_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/data/call_monitor_stream.dart';
import 'package:phone_agent/features/calls/data/focused_call_monitor_media.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/conversation/data/voice/signed_voice_socket.dart';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform production monitor signs upgrade and switches routes',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        var connections = 0, selected = 'earpiece';
        final socket = _Socket();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('phone_agent/pcm_output');
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'route') {
            selected = (call.arguments as Map)['select'] as String? ?? selected;
            return {'selected': selected, 'bluetooth': false};
          }
          return true;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(
                environment: 'dev',
                apiBaseUrl: 'http://127.0.0.1:1/agent',
                runtimeApiBaseUrl: 'http://127.0.0.1:2/runtime',
              ),
            ),
            sessionStoreProvider.overrideWithValue(_Store()),
            callSessionRepositoryProvider.overrideWithValue(_Repository()),
            taskVoiceTransportProvider.overrideWith(
              (ref) => SignedVoiceSocket(
                ref.watch(sessionControllerProvider.notifier),
                C1Transport(_Credentials()),
                connect: (uri, headers) async {
                  connections++;
                  expect(uri.path, '/runtime/ws/assistant/call/monitor');
                  expect(uri.port, 2);
                  expect(uri.queryParameters, {'ticket': 'synthetic-ticket'});
                  expect(headers['Authorization'], 'Bearer synthetic');
                  expect(headers['X-Sign'], matches(RegExp(r'^[0-9a-f]{64}$')));
                  return socket;
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(sessionControllerProvider.notifier).restore();
        final subscription = container.listen(
          callMonitorFactoryProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);
        final monitor = container.read(callMonitorFactoryProvider)();
        addTearDown(monitor.dispose);
        final media = monitor.createMedia() as FocusedCallMonitorMedia;
        expect(
          (media.delegate as CallMonitorStream).connect,
          container.read(taskVoiceTransportProvider).open,
        );
        await media.close();
        monitor.bind(CallSessionTarget(callId: 'synthetic-call'), active: true);
        final connecting = monitor.toggle();
        await Future<void>.delayed(Duration.zero);
        socket.events.add(List<int>.filled(64, 0));
        await connecting;
        expect(connections, 1);
        expect(monitor.snapshot.playing, isTrue);
        await monitor.select(CallAudioSource.speaker);
        expect(selected, 'speaker');
        expect(monitor.snapshot.source, CallAudioSource.speaker);
        await monitor.select(CallAudioSource.earpiece);
        expect(selected, 'earpiece');
        await monitor.stop();
        expect(socket.closed, isTrue);
      },
    );
  }
}

class _Store implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'synthetic',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(AuthSession session) async {}
}

class _Credentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async {
    expect(service, ApiService.agent);
    return const C1Credentials(
      apiKey: 'public-fixture',
      secret: 'public-fixture-secret',
      deviceId: '33333333-3333-4333-8333-333333333333',
      clientContext: 'e30',
    );
  }
}

class _Repository implements CallSessionRepository {
  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) async =>
      CallMonitorTicket(
        ticket: 'synthetic-ticket',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        sampleRate: 16000,
        channels: 1,
        encoding: 'PCM_S16LE',
      );
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) =>
      throw UnimplementedError();
  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) =>
      throw UnimplementedError();
}

class _Socket implements VoiceSocket {
  final events = StreamController<Object>();
  bool closed = false;
  @override
  Stream<Object> get messages => events.stream;
  @override
  void send(Object message) {}
  @override
  Future<void> close() async {
    closed = true;
    await events.close();
  }
}
