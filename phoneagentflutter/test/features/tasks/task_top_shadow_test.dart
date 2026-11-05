import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform first shadow survives viewport and return scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final disabled = debugDisableShadows;
          debugDisableShadows = false;
          addTearDown(() => debugDisableShadows = disabled);
          final boundary = GlobalKey();
          var refreshes = 0;
          var opens = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  backgroundColor: Colors.white,
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: TasksPage(
                      state: TaskState(
                        catalog: TaskCatalog(
                          List.generate(
                            12,
                            (i) => TaskRecord(
                              id: 'shadow-$i',
                              kind: TaskRecordKind.conversation,
                              title: '合成任务 $i',
                              summary: '合成说明',
                              status: TaskStatus.completed,
                              rawStatus: 'COMPLETED',
                            ),
                          ),
                        ),
                      ),
                      onRefresh: () async {
                        refreshes++;
                      },
                      onOpen: (_) => opens++,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final first = find.byKey(const ValueKey('shadow-0'));
          final top = tester.getTopLeft(first).dy;
          final viewport = tester.getTopLeft(find.byType(ListView)).dy;
          expect(top - viewport, 16);
          expect(
            tester.widget<ListView>(find.byType(ListView)).clipBehavior,
            Clip.hardEdge,
          );
          Future<void> checkShadow() async {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              int red(int y) => bytes.getUint8((y * image.width + 160) * 4);
              expect(
                red((top - 3).floor()),
                lessThan(255),
                reason: 'shadow must paint above first card',
              );
              expect(
                red(viewport.ceil()),
                255,
                reason: 'shadow must fade before the viewport boundary',
              );
              image.dispose();
            });
          }

          await checkShadow();
          await tester.tap(first);
          expect(opens, 1);
          final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          scroll.position.jumpTo(0);
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(first).dy, top);
          await checkShadow();
          await tester.drag(find.byType(ListView), const Offset(0, 300));
          await tester.pumpAndSettle();
          expect(refreshes, 1);
          expect(tester.takeException(), isNull);
          debugDisableShadows = disabled;
        },
      );
    }
  }
}
