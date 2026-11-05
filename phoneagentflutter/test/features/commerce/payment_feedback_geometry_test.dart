import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_active_sheet.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_upgrade_dialog.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_sheet.dart';
import 'membership_checkout_dialog_test.dart' as fixture;
import 'fake_commerce_repository.dart';

const _capture = String.fromEnvironment('COMMERCE_CAPTURE_DIR');
const _key = ValueKey('paymentFeedbackCapture');
void main() {
  setUpAll(() async {
    if (_capture.isEmpty) return;
    for (final entry in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    await Directory(_capture).create(recursive: true);
  });
  for (final width in [375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final kind in [
        'upgrade',
        'active',
        'success',
        'failure',
        'cancel',
        'incomplete',
      ]) {
        testWidgets('$kind sheet/dialog stays readable $width ${scale}x', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            RepaintBoundary(
              key: _key,
              child: MaterialApp(
                theme: ThemeData(
                  fontFamily: _capture.isEmpty ? null : 'ReferenceText',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  appBar: AppBar(title: const Text('会员与积分')),
                  body: Builder(
                    builder: (owner) => Center(
                      child: TextButton(
                        onPressed: () {
                          if (kind == 'upgrade') {
                            showDialog<void>(
                              context: owner,
                              builder: (_) => MembershipUpgradeDialog(
                                quote: fixture.quote,
                                product: fixture.product,
                                current: fixture.current,
                                agreementAccepted: true,
                                onLegal: () {},
                                onConfirm: () {},
                              ),
                            );
                          } else {
                            showModalBottomSheet<void>(
                              context: owner,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (sheet) => kind == 'active'
                                  ? MembershipActiveSheet(
                                      membership: fixture.current,
                                      onDone: () {},
                                    )
                                  : PurchaseFeedbackSheet(
                                      state: PurchaseState(
                                        order: sampleOrder(
                                          payment: kind == 'success'
                                              ? 'SUCCEEDED'
                                              : 'PROCESSING',
                                          fulfillment: kind == 'success'
                                              ? 'SUCCEEDED'
                                              : 'NOT_STARTED',
                                        ),
                                        nativeResultStatus: kind == 'cancel'
                                            ? '6001'
                                            : kind == 'failure'
                                            ? '4000'
                                            : '9000',
                                      ),
                                      upgrade: false,
                                      onDone: () {},
                                    ),
                            );
                          }
                        },
                        child: const Text('打开合成场景'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开合成场景'));
          await tester.pumpAndSettle();
          final title = switch (kind) {
            'upgrade' => '确认升级',
            'active' => '您已开通该套餐',
            'success' => '支付成功',
            'failure' => '支付失败',
            'cancel' => '支付已取消',
            _ => '本次支付未完成',
          };
          final rect = tester.getRect(find.text(title));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(find.text('支付结果确认中'), findsNothing);
          expect(find.text('微信购买'), findsNothing);
          if (kind != 'upgrade' && kind != 'active') {
            expect(find.textContaining('原订单'), findsNothing);
            expect(find.text('重新支付'), findsNothing);
            expect(find.byType(FilledButton), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          if (kind == 'upgrade' && scale == 2) {
            expect(
              tester.getSize(find.text('2099-04-01')).height,
              lessThan(48),
              reason: '大字日期不应被双列布局拆开',
            );
          }
          await _save(tester, '$kind-${width.toInt()}-${scale.toInt()}x');
          final action = find.text(
            kind == 'upgrade'
                ? '确认支付'
                : kind == 'active'
                ? '知道了'
                : '完成',
          );
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          final actionRect = tester.getRect(action);
          expect(actionRect.top, greaterThanOrEqualTo(0));
          expect(actionRect.bottom, lessThanOrEqualTo(844));
          expect(tester.takeException(), isNull);
          if (scale == 2 && kind == 'upgrade') {
            await _save(tester, 'upgrade-${width.toInt()}-2x-bottom');
          }
        });
      }
    }
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  if (_capture.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_key),
    );
    final pixels = await boundary.toImage();
    try {
      final png = await pixels.toByteData(format: ui.ImageByteFormat.png);
      await File('$_capture/$name.png').writeAsBytes(png!.buffer.asUint8List());
    } finally {
      pixels.dispose();
    }
  });
}
