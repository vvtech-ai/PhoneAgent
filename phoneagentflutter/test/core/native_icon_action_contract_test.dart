import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_detail_header.dart';
import 'package:phone_agent/features/identity/presentation/widgets/identity_widgets.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_enrollment.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_flow_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform identity icon role disabled fixed hit target large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          var calls = 0;
          try {
            for (final enabled in [true, false]) {
              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: IdentityIconButton(
                        label: '编辑身份',
                        asset: 1,
                        edit: true,
                        onTap: enabled ? () => calls++ : null,
                      ),
                    ),
                  ),
                ),
              );
              final action = find.bySemanticsLabel('编辑身份');
              final node = tester.getSemantics(action);
              expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(node.hasFlag(SemanticsFlag.isImage), isFalse);
              expect(node.hasFlag(SemanticsFlag.isEnabled), enabled);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                enabled,
              );
              expect(tester.getSize(action), const Size(48, 48));
              final center = tester.getCenter(action);
              for (final offset in [
                const Offset(-23, 0),
                const Offset(23, 0),
                const Offset(0, -23),
                const Offset(0, 23),
              ]) {
                await tester.tapAt(center + offset);
              }
              expect(calls, 4);
              expect(tester.takeException(), isNull);
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
      for (final kind in ['detail', 'candidate', 'identity']) {
        testWidgets(
          '$platform $kind icon callback belongs to route large=$large',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            if (large) tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  home: Builder(
                    builder: (root) => Scaffold(
                      body: TextButton(
                        child: const Text('打开'),
                        onPressed: () => Navigator.of(root).push<void>(
                          MaterialPageRoute(
                            builder: (page) {
                              void close() => Navigator.pop(page);
                              final widget = kind == 'detail'
                                  ? NativeDetailHeader(
                                      title: '合成详情',
                                      onBack: close,
                                    )
                                  : kind == 'candidate'
                                  ? CloneFlowHeader(
                                      step: CloneStep.candidate,
                                      onBack: close,
                                    )
                                  : IdentityIconButton(
                                      label: '编辑身份',
                                      asset: 1,
                                      onTap: close,
                                    );
                              return Scaffold(body: Column(children: [widget]));
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.tap(find.text('打开'));
              await tester.pumpAndSettle();
              final action = find.bySemanticsLabel(
                kind == 'identity' ? '编辑身份' : '返回',
              );
              final node = tester.getSemantics(action);
              expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
              expect(node.hasFlag(SemanticsFlag.isImage), isFalse);
              expect(
                node.getSemanticsData().hasAction(SemanticsAction.tap),
                isTrue,
              );
              expect(tester.getSize(action), const Size(48, 48));
              if (kind != 'identity') {
                final glyph = tester.widget<Text>(find.text('‹'));
                expect(glyph.textScaler, TextScaler.noScaling);
                expect(
                  tester.getSize(find.text('‹')).height,
                  kind == 'detail' ? 30 : 32,
                );
              }
              final callback = tester
                  .widget<IconButton>(find.byType(IconButton))
                  .onPressed!;
              callback();
              callback();
              await tester.pumpAndSettle();
              expect(find.text('打开'), findsOneWidget);
              await tester.tap(find.text('打开'));
              await tester.pumpAndSettle();
              callback();
              await tester.pumpAndSettle();
              expect(action, findsOneWidget);
              await tester.tap(action);
              await tester.pumpAndSettle();
              expect(find.text('打开'), findsOneWidget);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }
  }
}
