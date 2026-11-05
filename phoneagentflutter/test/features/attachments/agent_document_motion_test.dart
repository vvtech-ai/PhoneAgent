import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/agent_document_request.dart';
import 'package:phone_agent/features/attachments/presentation/controller/agent_document_controller.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/agent_document_host.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_agent_document_sheet.dart';

import 'agent_document_test.dart' show DocumentFake;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduceMotion in [false, true]) {
      testWidgets(
        'file motion and stale request $platform reduced=$reduceMotion',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final files = DocumentFake();
          final controller = AgentDocumentController(files, files);
          final focus = FocusNode();
          addTearDown(controller.dispose);
          addTearDown(focus.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion),
                child: child!,
              ),
              home: Scaffold(
                body: AgentDocumentHost(
                  controller: controller,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: TextField(focusNode: focus),
                  ),
                ),
              ),
            ),
          );
          final first = controller.resolve(
            const AgentDocumentRequest(title: '第一份文档'),
            isCurrent: () => true,
          );
          await tester.pump();
          final sheet = find.byType(NativeAgentDocumentSheet);
          final initialY = tester.getTopLeft(sheet).dy;
          await tester.pump(const Duration(milliseconds: 140));
          final middleY = tester.getTopLeft(sheet).dy;
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pump();
          expect(tester.getTopLeft(sheet).dy, closeTo(middleY, .01));
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 140));
          final finalY = tester.getTopLeft(sheet).dy;
          if (reduceMotion) {
            expect(initialY, closeTo(finalY, .01));
          } else {
            expect(initialY, greaterThan(middleY));
            expect(middleY, greaterThan(finalY));
          }
          expect(focus.canRequestFocus, isFalse);
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pump();
          expect(tester.getTopLeft(sheet).dy, closeTo(finalY, .01));
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pump();
          final staleChoose = tester
              .widget<NativeAgentDocumentSheet>(sheet)
              .onChoose;
          controller.cancel();
          expect((await first)!.status, 'USER_CANCELLED');
          await tester.pump();
          final second = controller.resolve(
            const AgentDocumentRequest(title: '第二份文档'),
            isCurrent: () => true,
          );
          await tester.pump();
          staleChoose();
          await tester.pump();
          expect(files.picks, 0);
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('第一份文档'), findsNothing);
          expect(find.text('第二份文档'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('agent-document-pick')));
          await tester.pumpAndSettle();
          expect(files.picks, 1);
          expect((await second)!.status, 'OK');
          expect(files.picks, 1);
          expect(focus.canRequestFocus, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
