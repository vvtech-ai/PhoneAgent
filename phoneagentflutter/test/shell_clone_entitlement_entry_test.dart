import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import '../tool/previews/shell_preview.dart';
import 'features/commerce/fake_commerce_repository.dart';
import 'support/pump_ui_transitions.dart';

class _NoClone extends FakeCommerceRepository {
  @override
  Future<MembershipCurrent> membership() async => const MembershipCurrent(
    level: 'FREE',
    entitlementVersionId: 1,
    benefits: {
      'cloneEntitlements': {'enabled': false},
    },
    terms: [],
  );
}

void main() {
  for (final sheet in [false, true]) {
    testWidgets(
      'actual shell clone button denies current rights: sheet=$sheet',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(home: ShellPreviewPage(commerce: _NoClone())),
        );
        Future<void> tap(Finder finder) async {
          await tester.pumpUntilUiSettled();
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpUntilUiSettled();
        }

        await tap(find.byKey(const ValueKey('tab-3')));
        await tap(find.byKey(const ValueKey('settings-models')));
        if (sheet) {
          await tap(find.byKey(const ValueKey('voices-QWEN_OMNI_PLUS')));
        }
        await tap(
          find.byKey(
            ValueKey(sheet ? 'voice-create-clone' : 'model-create-clone'),
          ),
        );
        expect(find.text('暂无声音克隆权益'), findsOneWidget);
        expect(find.text('选择声音克隆模型'), findsNothing);
        expect(find.byType(CloneFlowPage), findsNothing);
        if (sheet) {
          await tap(find.text('查看会员权益'));
          expect(find.byType(MembershipRoute), findsOneWidget);
        } else {
          await tap(find.text('取消'));
          expect(
            find.byKey(const ValueKey('model-create-clone')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
