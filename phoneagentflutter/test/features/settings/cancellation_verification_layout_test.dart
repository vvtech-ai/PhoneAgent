import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/auth_tokens.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_controller.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_verification_page.dart';
import 'package:phone_agent/features/auth/presentation/widgets/auth_widgets.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final compact in [false, true]) {
      testWidgets('verification layout $platform compact=$compact', (
        tester,
      ) async {
        final size = compact ? const Size(320, 568) : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final code = TextEditingController();
        final focus = FocusNode();
        addTearDown(code.dispose);
        addTearDown(focus.dispose);
        var resends = 0;
        final previewFont = Platform.environment['CANCELLATION_PREVIEW_FONT'];
        if (previewFont != null) {
          await tester.runAsync(() async {
            for (final entry in {
              'CancellationPreview': previewFont,
              // Match the engine fallback for styles without a font family.
              'Roboto': previewFont,
              'Ahem': previewFont,
              'MaterialIcons':
                  Platform.environment['CANCELLATION_PREVIEW_ICONS'],
            }.entries) {
              if (entry.value == null) continue;
              final loader = FontLoader(entry.key);
              loader.addFont(
                File(entry.value!).readAsBytes().then(ByteData.sublistView),
              );
              await loader.load();
            }
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: platform,
              fontFamily: previewFont == null ? null : 'CancellationPreview',
              colorScheme: ColorScheme.fromSeed(
                seedColor: AuthTokens.accent,
              ).copyWith(primary: AuthTokens.accent),
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(compact ? 2 : 1),
                viewInsets: EdgeInsets.only(bottom: compact ? 260 : 0),
              ),
              child: RepaintBoundary(
                key: const Key('verification-preview'),
                child: CancellationVerificationPage(
                  state: const CancellationState(
                    delivery: CancellationDelivery(
                      'sms',
                      'query',
                      '138****0000',
                      60,
                    ),
                    notice: '页面不得持续展示这条操作提示',
                  ),
                  code: code,
                  focusNode: focus,
                  onSend: () => resends++,
                  onRecover: null,
                  onBack: () {},
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(find.byType(AuthCodeInput), findsOneWidget);
        expect(find.byType(AuthInputGroup), findsNWidgets(6));
        expect(find.text('输入6位验证码'), findsOneWidget);
        expect(tester.getRect(find.text('输入6位验证码')).height, compact ? 80 : 40);
        expect(find.text('验证'), findsNothing);
        expect(find.text('继续注销'), findsNothing);
        expect(find.text('页面不得持续展示这条操作提示'), findsNothing);
        expect(find.textContaining('13800000000'), findsNothing);
        expect(tester.getTopLeft(find.text('输入6位验证码')).dx, 46);
        await tester.ensureVisible(find.text('重新发送'));
        await tester.tap(find.text('重新发送'));
        expect(resends, 1);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['CANCELLATION_PREVIEW_DIR'];
        if (output != null && platform == TargetPlatform.iOS && !compact) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('verification-preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/cancellation-verification.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
