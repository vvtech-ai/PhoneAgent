import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/membership_entitlements.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_benefit_list.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/clone_entry_membership_gate.dart';

MembershipCurrent current(
  Object? enabled, {
  bool queued = false,
  String level = 'PLUS',
}) => MembershipCurrent(
  level: level,
  entitlementVersionId: 1,
  benefits: {
    'cloneEntitlements': {'enabled': enabled},
  },
  terms: [],
  queuedEntitlements: queued
      ? const [
          MembershipQueueItem(
            entitlementId: 'queued',
            sourceOrderNo: 'queued-order',
            level: 'BASIC',
            months: 1,
            state: 'QUEUED',
            position: 1,
            firstGrantPoints: 1000,
            totalPeriods: 1,
            grantedPeriods: 0,
          ),
        ]
      : const [],
);
const published = CommerceCatalog(
  configVersionId: 1,
  revisionNo: 1,
  agreementVersion: 'v1',
  agreementUrl: 'https://example.com',
  supportEmail: '',
  products: [],
  benefitsByLevel: {
    'BASIC': {
      'cloneEntitlements': {'enabled': true},
    },
    'PLUS': {
      'cloneEntitlements': {'enabled': false},
    },
    'PREMIUM': {
      'cloneEntitlements': {'enabled': true},
    },
  },
);

void main() {
  for (final enabled in [true, false]) {
    testWidgets(
      'benefit displays published clone enabled=$enabled regardless of tier',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MembershipBenefitList(
                level: enabled ? 'FREE' : 'PREMIUM',
                benefits: {
                  'cloneEntitlements': {'enabled': enabled},
                },
              ),
            ),
          ),
        );
        expect(find.text('声音克隆', findRichText: true), findsOneWidget);
        expect(find.text(enabled ? '支持' : '暂不支持'), findsOneWidget);
      },
    );
  }
  Future<void> open(
    WidgetTester tester,
    Future<MembershipCurrent> Function() load, {
    required Future<void> Function() upgrade,
    Future<CommerceCatalog> Function()? catalog,
    bool Function()? isCurrent,
    ValueChanged<bool>? result,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final allowed = await checkCloneEntryMembership(
                  context,
                  load: load,
                  loadCatalog: catalog ?? () async => published,
                  isCurrent: isCurrent ?? () => true,
                  upgrade: upgrade,
                );
                result?.call(allowed);
              },
              child: const Text('克隆'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('克隆'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'denial recommends only higher supporting levels and rereads active rights on return',
    (tester) async {
      var reads = 0;
      var enabled = false;
      bool? allowed;
      await open(
        tester,
        () async {
          reads++;
          return current(enabled);
        },
        upgrade: () async {
          enabled = true;
        },
        result: (value) => allowed = value,
      );
      expect(find.textContaining('当前中级会员暂不支持声音克隆'), findsOneWidget);
      expect(find.textContaining('高级会员支持该功能，可前往查看会员权益'), findsOneWidget);
      expect(find.textContaining('初级会员'), findsNothing);
      await tester.tap(find.text('查看会员权益'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(allowed, true);
    },
  );
  testWidgets(
    'unchanged current rights remain denied on return despite purchased queue',
    (tester) async {
      var reads = 0;
      await open(tester, () async {
        reads++;
        return current(false, queued: true);
      }, upgrade: () async {});
      await tester.tap(find.text('查看会员权益'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('暂无声音克隆权益'), findsOneWidget);
    },
  );
  for (final invalid in [null, 'false', 0]) {
    testWidgets(
      'invalid current rights $invalid retries rather than suggesting upgrade',
      (tester) async {
        Object? enabled = invalid;
        bool? allowed;
        await open(
          tester,
          () async => current(enabled),
          upgrade: () async {},
          result: (v) => allowed = v,
        );
        expect(find.text('声音克隆权益读取失败'), findsOneWidget);
        expect(find.text('查看会员权益'), findsNothing);
        enabled = true;
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(allowed, true);
      },
    );
  }
  for (final publishedVersion in [0, 1]) {
    testWidgets(
      'FREE null rights require unpublished catalog ($publishedVersion)',
      (tester) async {
        bool? allowed;
        await open(
          tester,
          () async => const MembershipCurrent(
            level: 'FREE',
            entitlementVersionId: null,
            benefits: null,
            terms: [],
          ),
          catalog: () async => CommerceCatalog(
            configVersionId: publishedVersion,
            revisionNo: publishedVersion,
            agreementVersion: '',
            agreementUrl: '',
            supportEmail: '',
            products: [],
          ),
          upgrade: () async => fail('Legacy entry must not suggest upgrade'),
          result: (value) => allowed = value,
        );
        if (publishedVersion == 0) {
          expect(allowed, true);
          expect(find.text('声音克隆权益读取失败'), findsNothing);
        } else {
          expect(allowed, isNull);
          expect(find.text('声音克隆权益读取失败'), findsOneWidget);
        }
      },
    );
  }
  for (final benefits in <Map<String, Object?>?>[
    null,
    {},
    {'cloneEntitlements': {}},
    {'cloneEntitlements': 'false'},
  ]) {
    testWidgets(
      'missing or malformed current fields $benefits stay retryable',
      (tester) async {
        var recovered = false;
        bool? allowed;
        await open(
          tester,
          () async => recovered
              ? current(true)
              : MembershipCurrent(
                  level: 'PLUS',
                  entitlementVersionId: 1,
                  benefits: benefits,
                  terms: [],
                ),
          catalog: () async =>
              throw StateError('Unknown rights need no suggestions'),
          upgrade: () async => fail('Unknown rights must not open membership'),
          result: (value) => allowed = value,
        );
        expect(find.text('声音克隆权益读取失败'), findsOneWidget);
        expect(find.text('查看会员权益'), findsNothing);
        recovered = true;
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        expect(allowed, true);
      },
    );
  }
  for (final failure in [
    Exception('PRODUCT_UNAVAILABLE'),
    Exception('offline'),
  ]) {
    testWidgets(
      'known denial stays normal on catalog failure $failure and cancel blocks entry',
      (tester) async {
        bool? allowed;
        await open(
          tester,
          () async => current(false),
          catalog: () async => throw failure,
          upgrade: () async => fail('Cancel must not open membership'),
          result: (value) => allowed = value,
        );
        expect(find.textContaining('当前中级会员暂不支持声音克隆'), findsOneWidget);
        expect(find.textContaining('可前往会员页查看各等级权益'), findsOneWidget);
        expect(find.text('声音克隆权益读取失败'), findsNothing);
        expect(find.text('重试'), findsNothing);
        expect(find.text('查看会员权益'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(allowed, false);
      },
    );
  }
  for (final level in ['PLUS', 'PREMIUM']) {
    testWidgets('$level denial does not invent a higher supporting tier', (
      tester,
    ) async {
      await open(
        tester,
        () async => current(false, level: level),
        catalog: () async => const CommerceCatalog(
          configVersionId: 2,
          revisionNo: 1,
          agreementVersion: '',
          agreementUrl: '',
          supportEmail: '',
          products: [],
          benefitsByLevel: {
            'BASIC': {
              'cloneEntitlements': {'enabled': true},
            },
          },
        ),
        upgrade: () async {},
      );
      expect(find.textContaining('可前往会员页查看各等级权益'), findsOneWidget);
      expect(find.textContaining('会员支持该功能'), findsNothing);
      expect(find.text('重试'), findsNothing);
    });
  }
  testWidgets(
    'real current read failure still retries to latest active rights',
    (tester) async {
      var offline = true;
      bool? allowed;
      await open(
        tester,
        () async {
          if (offline) throw Exception('offline');
          return current(true);
        },
        upgrade: () async {},
        result: (value) => allowed = value,
      );
      expect(find.text('声音克隆权益读取失败'), findsOneWidget);
      expect(find.text('查看会员权益'), findsNothing);
      offline = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(allowed, true);
    },
  );
  testWidgets(
    'FREE null rights with failed catalog cannot prove legacy admission',
    (tester) async {
      bool? allowed;
      await open(
        tester,
        () async => const MembershipCurrent(
          level: 'FREE',
          entitlementVersionId: null,
          benefits: null,
          terms: [],
        ),
        catalog: () async => throw Exception('offline'),
        upgrade: () async {},
        result: (value) => allowed = value,
      );
      expect(find.text('声音克隆权益读取失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(allowed, false);
    },
  );
  for (final fails in [false, true]) {
    testWidgets(
      'known denial ignores late catalog after account invalidation failure=$fails',
      (tester) async {
        var owner = true;
        bool? allowed;
        final delayed = Completer<CommerceCatalog>();
        await open(
          tester,
          () async => current(false),
          upgrade: () async {},
          catalog: () => delayed.future,
          isCurrent: () => owner,
          result: (v) => allowed = v,
        );
        owner = false;
        if (fails) {
          delayed.completeError(Exception('offline'));
        } else {
          delayed.complete(published);
        }
        await tester.pumpAndSettle();
        expect(allowed, false);
        expect(find.text('暂无声音克隆权益'), findsNothing);
      },
    );
  }
}
