import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_list_row.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform long contacts build lazily and last row opens', (
      tester,
    ) async {
      final contacts = List.generate(
        1000,
        (i) =>
            ContactRecord(name: '合成联系人$i', phone: '$i', systemDialPhone: '$i'),
      );
      ContactRecord? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: ContactsPage(
              state: ContactsState(
                access: ContactAccess.authorized,
                contacts: contacts,
              ),
              onRefresh: () async {},
              onRequestPermission: () {},
              onOpen: (contact) => opened = contact,
            ),
          ),
        ),
      );
      expect(find.byType(ContactListRow).evaluate().length, lessThan(30));
      expect(find.text('合成联系人999'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('合成联系人999'),
        500,
        maxScrolls: 300,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('合成联系人999'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('合成联系人999'));
      expect(opened, same(contacts.last));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      '$platform error is not an empty result; permission settings are explicit',
      (tester) async {
        var settings = 0;
        Future<void> show(ContactsState state) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ContactsPage(
                state: state,
                onRefresh: () async {},
                onRequestPermission: () {},
                onOpen: (_) {},
                onSettings: () => settings++,
              ),
            ),
          ),
        );
        await show(
          const ContactsState(
            access: ContactAccess.authorized,
            deviceError: '合成读取失败',
          ),
        );
        expect(find.text('合成读取失败'), findsOneWidget);
        expect(find.text('暂无可显示的联系人'), findsNothing);
        expect(find.text('暂无联系人'), findsNothing);
        for (final access in [ContactAccess.denied, ContactAccess.limited]) {
          await show(ContactsState(access: access));
          expect(settings, access == ContactAccess.denied ? 0 : 1);
          await tester.tap(find.text('去设置授权'));
        }
        expect(settings, 2);
      },
    );
  }
}
