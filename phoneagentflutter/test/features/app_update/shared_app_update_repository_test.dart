import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/data/shared_app_update_repository.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  test(
    'startup and manual checks join one request; later calls really recheck',
    () async {
      final delegate = StartupRepositoryFake()
        ..pending = Completer<AppUpdateRelease>();
      final shared = SharedAppUpdateRepository(delegate);
      final first = shared.check(startupApp), second = shared.check(startupApp);
      expect(identical(first, second), true);
      delegate.pending!.complete(startupRelease());
      await first;
      await second;
      expect(delegate.checks, 1);
      await shared.check(startupApp);
      expect(delegate.checks, 2);
    },
  );
  test('failed request is released for explicit retry', () async {
    final delegate = StartupRepositoryFake()..fail = true;
    final shared = SharedAppUpdateRepository(delegate);
    await expectLater(shared.check(startupApp), throwsStateError);
    delegate.fail = false;
    await shared.check(startupApp);
    expect(delegate.checks, 2);
  });
}
