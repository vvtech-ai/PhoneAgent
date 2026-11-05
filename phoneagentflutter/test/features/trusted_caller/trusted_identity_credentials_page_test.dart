import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_caller.dart';
import 'package:phone_agent/features/trusted_caller/domain/trusted_incoming_identity.dart';
import 'package:phone_agent/features/trusted_caller/presentation/pages/trusted_identity_credentials_page.dart';
import 'package:phone_agent/features/trusted_caller/presentation/widgets/trusted_identity_certificate.dart';
import 'package:phone_agent/features/trusted_caller/presentation/widgets/trusted_identity_time.dart';

void main() {
  const owner = TrustedCallerOwner('synthetic', 'synthetic-phone', 1);
  TrustedIncomingIdentity identity(
    TrustedIdentityVerification verification, {
    int type = 0,
    bool long = false,
  }) => TrustedIncomingIdentity(
    owner: owner,
    eventId: 'synthetic',
    verification: verification,
    displayType: type,
    name: long ? '合成身份长名称合成身份长名称合成身份长名称' : '合成姓名',
    department: '合成部门',
    position: '合成职位',
    company: long ? '合成企业长名称合成企业长名称合成企业长名称' : '合成企业',
    caller: '12025550100',
    target: 'synthetic-phone',
    sequence: 'synthetic',
    serial: 'synthetic-serial',
    issuer: '合成颁发机构',
    callTime: '合成日期',
    issuedAt: '合成日期',
  );
  Future<void> show(
    WidgetTester tester,
    TrustedIncomingIdentity value, {
    double scale = 1,
    VoidCallback? back,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 568),
            textScaler: TextScaler.linear(scale),
          ),
          child: TrustedIdentityCredentialsPage(
            identity: value,
            onBack: back ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'only verified identity shows certificate and exact proof text',
    (tester) async {
      for (final phase in TrustedIdentityVerification.values) {
        await show(tester, identity(phase));
        expect(
          find.byType(TrustedIdentityCertificate),
          phase == TrustedIdentityVerification.verified
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          find.text('可信身份凭证'),
          phase == TrustedIdentityVerification.verified
              ? findsOneWidget
              : findsNothing,
        );
        if (phase == TrustedIdentityVerification.verified) {
          expect(find.text('本凭证仅用于证明合成日期通话主叫身份'), findsOneWidget);
          expect(find.textContaining('编号：synthetic-serial'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
  testWidgets('SDK type six always warns and cannot show certificate', (
    tester,
  ) async {
    await show(tester, identity(TrustedIdentityVerification.verified, type: 6));
    expect(find.text('此来电身份为未认证身份，建议您谨慎采信'), findsOneWidget);
    expect(find.text('可信身份凭证'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'short screen large text can scroll to real back button',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var backs = 0;
      await show(
        tester,
        identity(TrustedIdentityVerification.verified, long: true),
        scale: 2,
        back: () => backs++,
      );
      expect(tester.takeException(), isNull);
      final back = find.bySemanticsLabel('返回首页');
      final semantics = tester.ensureSemantics();
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(backs, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
  testWidgets('phone display type uses caller in header', (tester) async {
    await show(tester, identity(TrustedIdentityVerification.pending, type: 3));
    expect(
      find.textContaining('12025550100', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('合成姓名'), findsNothing);
    expect(find.text('正在验证来电身份…'), findsOneWidget);
  });
  test('presentation time preserves source seconds and milliseconds rule', () {
    expect(trustedIdentityTime(''), '本次');
    expect(trustedIdentityTime('合成日期'), '合成日期');
    expect(
      trustedIdentityTime('1700000000'),
      trustedIdentityTime('1700000000000'),
    );
    expect(trustedIdentityTime('1e100'), '1e100');
  });
}
