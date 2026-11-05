import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/contact_providers.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_route.dart';
import 'package:phone_agent/features/contacts/presentation/widgets/contact_remark_action.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform edit responds outside visible background', (
      tester,
    ) async {
      final port = PreviewContacts();
      final controller = ContactsController(port, port.directory);
      await controller.loadDevice();
      await controller.loadDirectory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contactsControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: const Scaffold(body: ContactsRoute()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('演示联系人，2025550101'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('编辑')),
        matchesSemantics(
          label: '编辑',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      final action = find.byType(ContactRemarkAction);
      await tester.tapAt(tester.getCenter(action) + const Offset(0, 22));
      await tester.pumpAndSettle();
      expect(find.text('编辑备注'), findsOneWidget);
      expect(controller.state.editing, isTrue);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.state.editing, isFalse);
      expect(find.byType(ContactDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
    testWidgets(
      '$platform contacts named 2x open and back callbacks only navigate once',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final port = PreviewContacts();
        final controller = ContactsController(port, port.directory);
        await controller.loadDevice();
        await controller.loadDirectory();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contactsControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(body: ContactsRoute()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.bySemanticsLabel('演示联系人，2025550101')),
          matchesSemantics(
            label: '演示联系人，2025550101',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        final choice = tester
            .widget<InkWell>(
              find.byKey(const ValueKey('contact-演示联系人-2025550101')),
            )
            .onTap!;
        choice();
        choice();
        await tester.pumpAndSettle();
        expect(find.byType(ContactDetailPage), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('返回联系人')),
          matchesSemantics(
            label: '返回联系人',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        final back = tester
            .widget<IconButton>(
              find
                  .ancestor(
                    of: find.byTooltip('返回联系人'),
                    matching: find.byType(IconButton),
                  )
                  .first,
            )
            .onPressed!;
        back();
        back();
        await tester.pumpAndSettle();
        expect(find.byType(ContactDetailPage), findsNothing);
        expect(find.bySemanticsLabel('演示联系人，2025550101'), findsOneWidget);
        expect(controller.state.selected, isNull);
        expect(controller.state.contacts.length, 3);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
