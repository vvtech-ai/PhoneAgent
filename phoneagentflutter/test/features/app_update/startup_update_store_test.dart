import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/data/secure_startup_update_store.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';
import 'package:phone_agent/features/app_update/domain/startup_update.dart';
import '../../support/startup_update_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'stores only date and force, survives recreation, isolates environment/package',
    () async {
      const store = SecureStartupUpdateStore('dev/api');
      await store.write(
        startupApp,
        const StartupUpdateRecord(
          lastSuccessDate: '2026-09-18',
          forceRequired: true,
        ),
      );
      final restored = await const SecureStartupUpdateStore(
        'dev/api',
      ).read(startupApp);
      expect(restored.forceRequired, true);
      expect(restored.lastSuccessDate, '2026-09-18');
      expect(
        (await const SecureStartupUpdateStore(
          'prod/api',
        ).read(startupApp)).forceRequired,
        false,
      );
      expect(
        (await store.read(
          const InstalledApp('com.other.app', '1', 1),
        )).forceRequired,
        false,
      );
      final values = await const FlutterSecureStorage().readAll();
      expect((jsonDecode(values.values.single) as Map).keys.toSet(), {
        'v',
        'day',
        'force',
      });
    },
  );
  test(
    'cross-instance writes and reads serialize at the same device scope',
    () async {
      const a = SecureStartupUpdateStore('same'),
          b = SecureStartupUpdateStore('same');
      final first = a.write(
        startupApp,
        const StartupUpdateRecord(forceRequired: true),
      );
      final last = b.write(
        startupApp,
        const StartupUpdateRecord(lastSuccessDate: '2026-09-18'),
      );
      final read = a.read(startupApp);
      await first;
      await last;
      expect((await read).forceRequired, false);
      expect((await read).lastSuccessDate, '2026-09-18');
    },
  );
  test(
    'malformed stored policy fails explicitly, not a silent force reset',
    () async {
      const store = SecureStartupUpdateStore('same');
      await store.write(
        startupApp,
        const StartupUpdateRecord(forceRequired: true),
      );
      const secure = FlutterSecureStorage();
      final key = (await secure.readAll()).keys.single;
      await secure.write(key: key, value: '{"v":1,"force":"false","day":null}');
      await expectLater(store.read(startupApp), throwsFormatException);
    },
  );
}
