import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/features/contacts/data/device_contact_channel.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';

// Run only on an isolated test installation with contacts access NOT granted.
// It verifies native registration/no-prompt behavior, not real contact content.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native contacts channel reports ungranted access without prompting',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('通讯录权限只读检查'))),
      );
      final result = await const DeviceContactChannel().load();
      expect(
        result.access,
        anyOf(
          ContactAccess.notDetermined,
          ContactAccess.denied,
          ContactAccess.restricted,
        ),
      );
      expect(result.rows, isEmpty);
      await tester.pumpAndSettle();
      expect(find.text('通讯录权限只读检查'), findsOneWidget);
    },
  );
}
