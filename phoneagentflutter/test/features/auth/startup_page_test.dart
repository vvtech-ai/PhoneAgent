import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_route.dart';
import 'package:phone_agent/features/auth/presentation/widgets/startup_page.dart';

class _PendingStore implements SessionStore {
  final result = Completer<AuthSession?>();
  @override
  Future<AuthSession?> read() => result.future;
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('startup stays centered and white in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const StartupPage(),
        ),
      );
      final image = find.byType(Image);
      expect(tester.getSize(image), const Size(120, 120));
      expect(tester.getCenter(image), const Offset(195, 422));
      expect(
        tester.widget<ColoredBox>(find.byType(ColoredBox).last).color,
        Colors.white,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restore failure leaves startup immediately and offers retry', (
    tester,
  ) async {
    final store = _PendingStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: AuthRoute()),
      ),
    );
    expect(find.byType(StartupPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(StartupPage), findsOneWidget);
    store.result.completeError(StateError('synthetic storage failure'));
    // Flush the future completion, then render Riverpod’s scheduled frame.
    await tester.pump();
    await tester.pump();
    expect(find.byType(StartupPage), findsNothing);
    expect(find.text('无法读取登录状态，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
