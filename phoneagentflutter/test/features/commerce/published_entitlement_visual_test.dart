import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_benefit_list.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/points_offer_card.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_entry_membership_gate.dart';
import 'points_offer_discount_test.dart' as fixture;

const capture = String.fromEnvironment('COMMERCE_CAPTURE_DIR');
const boundaryKey = ValueKey('published-entitlement-visual');

void main() {
  setUpAll(() async {
    if (capture.isEmpty) return;
    for (final entry in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    await Directory(capture).create(recursive: true);
  });
  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    final scale = size.width == 320 ? 2.0 : 1.0;
    for (final kind in [
      'membership',
      'apple-points',
      'upgrade',
      'read-failure',
    ]) {
      testWidgets(
        '$kind published entitlement layout ${size.width} ${scale}x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final offer = fixture.offer();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  fontFamily: capture.isEmpty ? null : 'ReferenceText',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: Text(kind == 'membership' ? '会员权益' : '购买积分'),
                    ),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: kind == 'membership'
                          ? const MembershipBenefitList(
                              level: 'PLUS',
                              benefits: {
                                'monthlyBasePoints': 10000,
                                'monthlyBonusPoints': 2000,
                                'cloneEntitlements': {'enabled': true},
                              },
                            )
                          : kind == 'apple-points'
                          ? PointsOfferCard(
                              state: CatalogState(
                                requiresPlatformProducts: true,
                                platformStatus: PlatformProductsStatus.ready,
                                platformProducts: {
                                  'member-sku': fixture.apple(
                                    '4.5',
                                    display: 'US\$4.50',
                                  ),
                                  'regular-sku': fixture.apple(
                                    '5',
                                    display: 'US\$5.00',
                                  ),
                                },
                              ),
                              offer: offer,
                              selected: true,
                              onSelect: () {},
                            )
                          : TextButton(
                              onPressed: () => checkCloneEntryMembership(
                                context,
                                load: () async {
                                  if (kind == 'read-failure') {
                                    throw Exception('offline');
                                  }
                                  return const MembershipCurrent(
                                    level: 'PLUS',
                                    entitlementVersionId: 1,
                                    benefits: {
                                      'cloneEntitlements': {'enabled': false},
                                    },
                                    terms: [],
                                  );
                                },
                                loadCatalog: () async => const CommerceCatalog(
                                  configVersionId: 1,
                                  revisionNo: 1,
                                  agreementVersion: '',
                                  agreementUrl: '',
                                  supportEmail: '',
                                  products: [],
                                  benefitsByLevel: {
                                    'BASIC': {
                                      'cloneEntitlements': {'enabled': true},
                                    },
                                    'PREMIUM': {
                                      'cloneEntitlements': {'enabled': true},
                                    },
                                  },
                                ),
                                isCurrent: () => true,
                                upgrade: () async {},
                              ),
                              child: const Text('声音克隆'),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (kind == 'upgrade' || kind == 'read-failure') {
            await tester.tap(find.text('声音克隆'));
            await tester.pumpAndSettle();
            final action = kind == 'upgrade' ? '查看会员权益' : '重试';
            await tester.ensureVisible(find.text(action));
            final confirm = find.widgetWithText(TextButton, action);
            expect(
              tester.getRect(confirm).bottom,
              lessThanOrEqualTo(size.height),
            );
            expect(confirm.hitTestable(), findsOneWidget);
            if (kind == 'upgrade') {
              expect(find.textContaining('当前中级会员暂不支持声音克隆'), findsOneWidget);
              expect(find.textContaining('高级会员支持该功能'), findsOneWidget);
              expect(find.textContaining('初级会员'), findsNothing);
              expect(find.text('重试'), findsNothing);
            } else {
              expect(find.text('声音克隆权益读取失败'), findsOneWidget);
              expect(find.text('查看会员权益'), findsNothing);
            }
          } else if (kind == 'membership') {
            expect(find.text('声音克隆', findRichText: true), findsOneWidget);
            expect(find.text('支持'), findsOneWidget);
          } else {
            expect(find.text('US\$4.50'), findsOneWidget);
            expect(find.text('US\$5.00'), findsOneWidget);
            expect(find.text('9折'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          if (capture.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(boundaryKey),
              );
              final pixels = await boundary.toImage();
              try {
                final png = await pixels.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$capture/$kind-${size.width.toInt()}-${scale.toInt()}x.png',
                ).writeAsBytes(png!.buffer.asUint8List());
              } finally {
                pixels.dispose();
              }
            });
          }
        },
      );
    }
  }
}
