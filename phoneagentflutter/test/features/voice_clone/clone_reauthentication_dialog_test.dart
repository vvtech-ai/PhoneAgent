import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:phone_agent/core/design/native_gradient_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/preview_clone_creation_port.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_creation_sheet.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_reauthentication_dialog.dart';

const _capture = bool.fromEnvironment('CAPTURE_CLONE_DIALOG');
const _captureKey = Key('clone-dialog-capture');
const _cancel = Key('clone-reauth-cancel');
const _confirm = Key('clone-reauth-confirm');

Future<void> _open(WidgetTester tester, {ValueChanged<bool?>? onResult}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _capture
          ? ThemeData(
              fontFamily: 'ReferenceText',
              cupertinoOverrideTheme: const CupertinoThemeData(
                textTheme: CupertinoTextThemeData(
                  actionTextStyle: TextStyle(fontFamily: 'ReferenceText'),
                ),
              ),
            )
          : null,
      builder: (_, child) => RepaintBoundary(key: _captureKey, child: child),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                barrierColor: const Color(0x8A000000),
                builder: (_) => const CloneReauthenticationDialog(
                  modelName: 'QwenOmniPlus',
                ),
              );
              onResult?.call(result);
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!_capture) return;
    const fontPath = String.fromEnvironment('UI_PREFLIGHT_FONT');
    if (fontPath.isEmpty) throw StateError('Explicit capture font required');
    final loader = FontLoader('ReferenceText')
      ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [const Size(320, 480), const Size(390, 844)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$platform action layout $size scale=$scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final semantics = tester.ensureSemantics();
            try {
              await _open(tester);
              final cancel = find.byKey(_cancel);
              final confirm = find.byKey(_confirm);
              await tester.ensureVisible(confirm);
              await tester.pumpAndSettle();
              final left = tester.getRect(cancel);
              final right = tester.getRect(confirm);
              expect(left.width, closeTo(right.width, .01));
              expect(left.top, right.top);
              expect(left.height, right.height);
              expect(left.height, greaterThanOrEqualTo(48));
              expect(left.right, lessThan(right.left));
              expect(right.bottom, lessThanOrEqualTo(size.height));
              for (final label in ['取消', '继续重新认证']) {
                final node = tester.getSemantics(find.bySemanticsLabel(label));
                expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
                expect(
                  node.getSemanticsData().hasAction(SemanticsAction.tap),
                  isTrue,
                );
              }
              expect(
                find.byKey(const Key('clone-reauth-horizontal-divider')),
                findsNothing,
              );
              expect(
                find.byKey(const Key('clone-reauth-vertical-divider')),
                findsNothing,
              );
              expect(
                find.descendant(
                  of: find.byType(CloneReauthenticationDialog),
                  matching: find.byType(TextButton),
                ),
                findsNWidgets(2),
              );
              expect(
                tester
                    .widget<NativeGradientAction>(
                      find.ancestor(
                        of: confirm,
                        matching: find.byType(NativeGradientAction),
                      ),
                    )
                    .tone,
                NativeActionTone.primary,
              );
              expect(tester.takeException(), isNull);
              if (_capture) {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(_captureKey),
                );
                await tester.runAsync(() async {
                  final image = await boundary.toImage(pixelRatio: 2);
                  final bytes = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final file = File(
                    '.local/ui-reference/clone-reauth-actions/'
                    '${platform.name}-${size.width.toInt()}-$scale.png',
                  );
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(bytes!.buffer.asUint8List());
                  image.dispose();
                });
              }
            } finally {
              await tester.pumpWidget(const SizedBox());
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant({platform}),
        );
      }
    }

    testWidgets(
      '$platform cancel continue and back preserve picker flow',
      (tester) async {
        CloneCreationLaunch? launch;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    launch = await showCloneCreationSheet(
                      context,
                      PreviewCloneCreationPort(CloneCreationScenario.existing),
                    );
                  },
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        Future<void> select() async {
          await tester.tap(find.text('QwenOmniPlus'));
          await tester.pumpAndSettle();
          expect(find.byType(CloneReauthenticationDialog), findsOneWidget);
        }

        await select();
        await tester.tap(find.byKey(_cancel));
        await tester.pumpAndSettle();
        expect(find.byType(CloneCreationSheet), findsOneWidget);
        expect(find.byType(CloneReauthenticationDialog), findsNothing);
        await select();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CloneCreationSheet), findsOneWidget);
        expect(launch, isNull);
        await select();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(CloneCreationSheet), findsOneWidget);
        expect(find.byType(CloneReauthenticationDialog), findsNothing);
        expect(launch, isNull);
        await select();
        // Successful continuation returns the existing launch; this bare host
        // intentionally has no authentication route or real SDK attached.
        await tester.tap(find.byKey(_confirm));
        await tester.pumpAndSettle();
        expect(find.byType(CloneCreationSheet), findsNothing);
        expect(launch?.start, CloneCreationStart.authentication);
        expect(find.text('打开'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform old or duplicate actions cannot pop other routes',
      (tester) async {
        final results = <bool?>[];
        await _open(tester, onResult: results.add);
        final oldCancel = tester
            .widget<TextButton>(find.byKey(_cancel))
            .onPressed!;
        final oldConfirm = tester
            .widget<TextButton>(find.byKey(_confirm))
            .onPressed!;
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('覆盖页')),
          ),
        );
        await tester.pumpAndSettle();
        oldCancel();
        oldConfirm();
        await tester.pumpAndSettle();
        expect(find.text('覆盖页'), findsOneWidget);
        expect(results, isEmpty);
        navigator.pop();
        await tester.pumpAndSettle();
        oldConfirm();
        oldCancel();
        await tester.pumpAndSettle();
        expect(results, [true]);
        oldConfirm();
        oldCancel();
        await tester.pumpAndSettle();
        expect(find.text('打开'), findsOneWidget);
        expect(results, [true]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );

    testWidgets(
      '$platform cancelled gradient-button gesture does not confirm',
      (tester) async {
        final results = <bool?>[];
        await _open(tester, onResult: results.add);
        final confirm = find.byKey(_confirm);
        final gesture = await tester.startGesture(tester.getCenter(confirm));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        await tester.tap(find.byKey(_cancel));
        await tester.pumpAndSettle();
        expect(results, [false]);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
