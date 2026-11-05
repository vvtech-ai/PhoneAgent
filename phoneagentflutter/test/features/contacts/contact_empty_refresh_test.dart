import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('authorized empty can pull refresh at large text $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var refreshes = 0;
      var permissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ContactsPage(
              state: const ContactsState(access: ContactAccess.authorized),
              onRefresh: () async {
                refreshes++;
              },
              onRequestPermission: () {
                permissions++;
              },
              onOpen: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('暂无联系人'), findsOneWidget);
      expect(find.text('刷新'), findsNothing);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(permissions, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
