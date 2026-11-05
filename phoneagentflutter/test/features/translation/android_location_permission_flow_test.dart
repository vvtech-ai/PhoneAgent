import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/features/dialer/presentation/widgets/dial_location_host.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_location_controller.dart';

class _Location implements TranslationLocationSource, TranslationLocationStore {
  int calls = 0, settings = 0;
  bool settingsFail = false;
  TrustedTranslationLocation? cached;
  @override
  Future<TranslationLocationResult> locate() async {
    calls++;
    return const TranslationLocationResult(
      TranslationLocationStatus.resolved,
      countryIso: 'US',
    );
  }

  @override
  Future<void> openSettings() async {
    settings++;
    if (settingsFail) throw StateError('synthetic');
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<TrustedTranslationLocation?> read() async => cached;
  @override
  Future<void> write(TrustedTranslationLocation value) async {
    cached = value;
  }
}

void main() {
  late _Location source;
  late TranslationLocationController controller;
  late TranslationLocationStatus permission;
  late int checks;
  setUp(() {
    source = _Location();
    permission = TranslationLocationStatus.blocked;
    checks = 0;
    controller = TranslationLocationController(
      source,
      source,
      readAndroidPermission: () async {
        checks++;
        return permission;
      },
    );
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test(
    'blocked card opens settings directly, granted return locates once',
    () async {
      await controller.load();
      await controller.requestLocation();
      await controller.requestLocation();
      expect(source.settings, 1);
      expect(source.calls, 0);
      expect(controller.snapshot.error, isEmpty);
      permission = TranslationLocationStatus.resolved;
      await controller.resumeAfterSettings();
      await controller.resumeAfterSettings();
      expect(checks, 2);
      expect(source.calls, 1);
      expect(source.cached!.countryIso, 'US');
    },
  );
  test('denied or granted card uses existing system locate path', () async {
    permission = TranslationLocationStatus.denied;
    await controller.requestLocation();
    expect(source.calls, 1);
    expect(source.settings, 0);
  });
  test('ungranted return only checks status without asking again', () async {
    await controller.requestLocation();
    permission = TranslationLocationStatus.denied;
    await controller.resumeAfterSettings();
    expect(source.calls, 0);
    expect(controller.snapshot.status, TranslationLocationStatus.denied);
  });
  test('settings launch failure remains retryable', () async {
    source.settingsFail = true;
    await controller.requestLocation();
    expect(controller.snapshot.status, TranslationLocationStatus.blocked);
    source.settingsFail = false;
    await controller.requestLocation();
    expect(source.settings, 2);
    expect(source.calls, 0);
  });
  test(
    'cancel ignores late read and never opens settings or locates',
    () async {
      final gate = Completer<TranslationLocationStatus>();
      controller.dispose();
      controller = TranslationLocationController(
        source,
        source,
        readAndroidPermission: () => gate.future,
      );
      final pending = controller.requestLocation();
      controller.cancel();
      gate.complete(TranslationLocationStatus.blocked);
      await pending;
      expect(source.calls, 0);
      expect(source.settings, 0);
    },
  );
  test('leaving settings owner cancels automatic return work', () async {
    await controller.requestLocation();
    controller.cancel();
    permission = TranslationLocationStatus.resolved;
    await controller.resumeAfterSettings();
    expect(source.calls, 0);
  });
  test(
    'iOS generic path keeps manual settings return and no automatic locate',
    () async {
      controller.dispose();
      controller = TranslationLocationController(source, source);
      await controller.openSettings();
      await controller.resumeAfterSettings();
      expect(controller.snapshot.error, contains('请点击获取'));
      expect(source.calls, 0);
      await controller.requestLocation();
      expect(source.calls, 1);
    },
  );
  testWidgets('blocked return keeps settings action label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationLocationProvider.overrideWith((_) => controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DialLocationHost(
              hideWhenSimulated: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('dial-location-request')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('前往设置'), findsOneWidget);
    expect(source.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'country card returns from settings and refreshes automatically',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            translationLocationProvider.overrideWith((_) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DialLocationHost(
                hideWhenSimulated: false,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('dial-location-request')));
      await tester.pumpAndSettle();
      expect(source.settings, 1);
      expect(source.calls, 0);
      permission = TranslationLocationStatus.resolved;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      expect(find.byKey(const Key('dial-location-select')), findsOneWidget);
      expect(find.textContaining('返回后，请点击获取'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
