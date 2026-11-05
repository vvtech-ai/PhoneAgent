import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/controller/identity_controller.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_page.dart';

void main() {
  testWidgets(
    'native profile top actions and external clone remain usable at large type',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: IdentityPage(
                state: const IdentityState(
                  profile: IdentityProfile(
                    accountId: 'synthetic',
                    name: '长姓名用于验证身份资料内容换行',
                    contactPhone: '13800000000',
                    verificationStatus: 'VERIFIED',
                  ),
                ),
                actions: IdentityActions(
                  back: () {},
                  retry: () {},
                  edit: () => actions.add('edit'),
                  cancel: () {},
                  save: () {},
                  delete: () => actions.add('delete'),
                  models: () => actions.add('models'),
                  name: (_) {},
                  phone: (_) {},
                  gender: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final edit = find.byTooltip('编辑身份');
      final delete = find.byTooltip('删除身份');
      expect(
        tester.getCenter(edit).dy,
        lessThan(tester.getTopLeft(find.text('姓名')).dy),
      );
      expect(
        tester.getCenter(delete).dy,
        lessThan(tester.getTopLeft(find.text('姓名')).dy),
      );
      for (final target in [edit, delete, find.text('声音克隆')]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(actions, ['edit', 'delete', 'models']);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
