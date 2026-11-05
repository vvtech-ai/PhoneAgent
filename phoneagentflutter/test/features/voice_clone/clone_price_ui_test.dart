import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/clone_diagnostics.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/pages/clone_flow_page.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_creation_sheet.dart';
import 'clone_model_price_contract_test.dart' show PricePort;
import 'clone_flow_diagnostics_test.dart' show services;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform picker displays actual quote; unavailable quote blocks creation',
      (tester) async {
        for (final price in <int?>[650, null]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: CloneCreationSheet(
                  key: ValueKey(price),
                  port: PricePort(price, 600),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('300'), findsNothing);
          expect(find.text(price == null ? '--' : '650'), findsOneWidget);
          await tester.tap(find.text('Server model'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              price == null ? '暂时无法获取声音克隆价格，请稍后重试' : '积分不足，声音克隆需要 ✦650',
            ),
            findsOneWidget,
          );
        }
      },
    );
    testWidgets(
      '$platform rerecord confirmation uses frozen quote and cancellation makes no new attempt',
      (tester) async {
        final p = PreviewCloneFlow();
        final c = CloneFlowController(
          const CloneCreationLaunch(
            CloneCreationModel(
              id: PreviewCloneFlow.model,
              name: 'Synthetic',
              pricePoints: 650,
            ),
            CloneCreationStart.authentication,
          ),
          services(p, CloneDiagnostics(null)),
        );
        await c.start();
        c.agree(true);
        await c.next();
        await c.submitIdentity('演练', '000000200001010005');
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: CloneFlowPage(controller: c, preview: true),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('重新录制'));
        await tester.pumpAndSettle();
        expect(find.textContaining('再次扣除 650 积分'), findsOneWidget);
        expect(find.textContaining('再次扣除 300 积分'), findsNothing);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(p.verification.initializes, 1);
        expect(p.candidates.fromVerified, 1);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.pump();
      },
    );
  }
}
