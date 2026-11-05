import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/controller/identity_controller.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_page.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'profile field spacing and guarded actions at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final calls = <String>[];
        Future<void> render({bool busy = false}) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IdentityPage(
                state: IdentityState(
                  operation: busy
                      ? IdentityOperation.deleting
                      : IdentityOperation.idle,
                  profile: const IdentityProfile(
                    accountId: 'synthetic',
                    name: '演练用户',
                    gender: '不透露',
                    verificationStatus: 'VERIFIED',
                  ),
                ),
                actions: IdentityActions(
                  back: () {},
                  retry: () {},
                  edit: () => calls.add('edit'),
                  cancel: () {},
                  save: () {},
                  delete: () => calls.add('delete'),
                  models: () => calls.add('clone'),
                  name: (_) {},
                  phone: (_) {},
                  gender: (_) {},
                ),
              ),
            ),
          ),
        );
        await render();
        final header = find
            .ancestor(of: find.byTooltip('编辑身份'), matching: find.byType(Row))
            .first;
        final field = find
            .ancestor(
              of: find.text('姓名'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            )
            .first;
        expect(
          tester
                  .getTopLeft(
                    find
                        .descendant(
                          of: field,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .dy -
              tester.getBottomLeft(header).dy,
          closeTo(12, .01),
        );
        expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
        for (final label in ['编辑身份', '删除身份']) {
          final action = find.byTooltip(label);
          expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          await tester.tap(action);
          await tester.pump();
        }
        expect(calls, ['edit', 'delete']);
        await render(busy: true);
        await tester.pumpAndSettle();
        for (final label in ['编辑身份', '删除身份']) {
          await tester.ensureVisible(find.byTooltip(label));
          await tester.tap(find.byTooltip(label));
        }
        expect(calls, ['edit', 'delete']);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
