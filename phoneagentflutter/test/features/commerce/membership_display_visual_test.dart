import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_benefit_list.dart';
import 'membership_reference_fixture.dart';

// Production Flutter widgets with synthetic published configuration; no device,
// account, payment or backend operation is performed by these visual checks.
void main() {
  const capture = String.fromEnvironment('COMMERCE_CAPTURE_DIR');
  setUpAll(() async {
    if (capture.isEmpty) return;
    for (final entry in const {
      'ReferenceText': String.fromEnvironment('UI_PREFLIGHT_FONT'),
      'MaterialIcons': String.fromEnvironment('UI_PREFLIGHT_ICON_FONT'),
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            File(entry.value).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await Directory(capture).create(recursive: true);
  });

  for (final scenario in ['regular', 'mixed', 'narrow-large', 'long-models']) {
    testWidgets('published benefit page layout $scenario', (tester) async {
      final small = scenario == 'narrow-large';
      tester.view.physicalSize = small
          ? const Size(320, 568)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = membershipReferenceFixture('BASIC');
      final catalog = base.catalog!;
      final benefits = {
        ...catalog.benefitsByLevel['BASIC']!,
        'monthlyBasePoints': 3900,
        'monthlyBonusPoints': 600,
        'displayOptions': {
          'monthlyPoints': {
            'fontSize': scenario == 'regular' ? 'REGULAR' : 'LARGE',
          },
        },
        'displayItems': [
          {
            'id': 'clone',
            'title': '声音克隆',
            'description': small
                ? '让 AI 使用熟悉的声音沟通；较长的权益说明会自动换行，完整呈现，不遮挡下方内容。'
                : '让 AI 使用自己的声音，完成自然的电话沟通',
            'fontSize': 'REGULAR',
          },
          {
            'id': 'preview',
            'title': scenario == 'long-models'
                ? '可用模型 QwenOmniPlus、Seeduplex、Seeduplex V3、IndexTTS 2.5 实时通话（千问听略）、Qwen Audio 3.1 实时通话'
                : '新模型抢先体验',
            'description': '优先体验新上线的通话模型',
            'fontSize': scenario == 'regular' ? 'REGULAR' : 'LARGE',
          },
          {
            'id': 'batch',
            'title': '8 人批量联系人任务',
            'description': '一次安排多位联系人，轻松处理重复沟通',
            'fontSize': 'REGULAR',
          },
        ],
      };
      final state = CatalogState(
        selectedLevel: 'BASIC',
        channelAvailable: true,
        membership: base.membership,
        catalog: CommerceCatalog(
          configVersionId: catalog.configVersionId,
          revisionNo: catalog.revisionNo,
          agreementVersion: catalog.agreementVersion,
          agreementUrl: catalog.agreementUrl,
          supportEmail: catalog.supportEmail,
          products: catalog.products,
          benefitsByLevel: {...catalog.benefitsByLevel, 'BASIC': benefits},
        ),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: capture.isEmpty ? null : 'ReferenceText',
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(small ? 2 : 1)),
              child: child!,
            ),
            home: MembershipPage(
              state: state,
              availablePoints: 900,
              heldPoints: 0,
              onBack: () {},
              onRefresh: () async {},
              onPoints: () {},
              onOrders: () {},
              onLedger: () {},
              onBuy: () {},
              onLevel: (_) {},
              onMonths: (_) {},
              onSupport: () {},
              onRestore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(MembershipBenefitList));
      await tester.pumpAndSettle();
      expect(find.text('每月到账 4,500 积分', findRichText: true), findsOneWidget);
      expect(find.text('其中含赠送 600 积分'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(MembershipBenefitList));
      expect(card.left, greaterThanOrEqualTo(16));
      expect(
        card.right,
        lessThanOrEqualTo(tester.view.physicalSize.width - 16),
      );
      if (capture.isNotEmpty) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '$capture/membership-$scenario.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
