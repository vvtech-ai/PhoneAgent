import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_page.dart';
import 'invite_fakes.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform current invite code is readable and selectable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final repository = _ChangingCode();
      final device = FakeInviteDevice();
      final controller = InviteController(repository, device);
      try {
        await controller.refresh();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inviteControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const InvitePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('ABCD'), findsOneWidget);
        await tester.longPress(find.text('ABCD'));
        await tester.pumpAndSettle();
        final editable = tester.widget<EditableText>(find.byType(EditableText));
        expect(editable.controller.selection.isCollapsed, false);
        expect(
          editable.controller.selection.textInside(editable.controller.text),
          'ABCD',
        );
        repository.current = const InviteCode(
          'EFGH',
          'https://example.test/invite/?code=EFGH',
          '2035-01-01T00:00:00Z',
          1,
          0,
          4,
          InviteOverview(sampleActivity, null),
        );
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('ABCD'), findsNothing);
        expect(find.bySemanticsLabel('EFGH'), findsOneWidget);
        expect(find.text('ABCD'), findsNothing);
        expect(find.text('EFGH'), findsOneWidget);
        expect(device.copied, isNull);
        expect(device.image, isNull);
        expect(repository.events, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        semantics.dispose();
        await device.received.close();
      }
    });
  }
}

class _ChangingCode extends FakeInviteRepository {
  InviteCode current = sampleCode;
  @override
  Future<InviteCode> code() async => current;
}
