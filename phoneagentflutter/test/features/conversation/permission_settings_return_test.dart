import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/tools/permission_settings_return.dart';

void main() {
  testWidgets('launch failure propagates and lifecycle observer is removed', (
    tester,
  ) async {
    await expectLater(
      waitForPermissionSettingsReturn(
        () async => throw StateError('synthetic'),
      ),
      throwsStateError,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings return timeout cleans up without accepting a late resume',
    (tester) async {
      final returned = waitForPermissionSettingsReturn(
        () async {},
        timeout: const Duration(milliseconds: 20),
      );
      final check = expectLater(returned, throwsA(isA<TimeoutException>()));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 20));
      await check;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
