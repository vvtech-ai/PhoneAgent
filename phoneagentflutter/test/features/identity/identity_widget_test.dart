import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/domain/identity_deletion_cleanup.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_route.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    _Repository repo, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          identityDeletedEffectProvider.overrideWithValue(
            () => IdentityDeletionCleanup(
              markSkipped: () async {
                repo.deletedEffects++;
              },
              clearRecording: () async {},
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push<IdentityDestination>(
                    context,
                    MaterialPageRoute(builder: (_) => const IdentityRoute()),
                  ),
                  child: const Text('设置入口'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('设置入口'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'load failure retries; first optional-phone save stays; existing edit returns',
    (tester) async {
      final repo = _Repository()..failLoad = true;
      await open(tester, repo);
      expect(find.text('身份资料加载失败，请重试'), findsOneWidget);
      expect(find.text('填写身份信息'), findsNothing);
      repo.failLoad = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('填写身份信息'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('identity-name')),
        '测试姓名',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(find.text('身份资料已保存'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(repo.value.contactPhone, isEmpty);
      expect(find.text('我的身份'), findsOneWidget);
      expect(find.text('测试姓名'), findsOneWidget);
      expect(find.text('已认证'), findsNothing);
      await tester.tap(find.byTooltip('编辑身份'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('identity-name')),
        '新姓名',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.writes, 2);
      expect(find.text('设置入口'), findsOneWidget);
      expect(find.text('身份资料已保存'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      // Both successful saves keep their own notice across the route pop.
      expect(find.text('身份资料已保存'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(find.text('身份资料已保存'), findsNothing);
    },
  );

  testWidgets(
    'verified name read-only; invalid phone and network failure keep form',
    (tester) async {
      final repo = _Repository()
        ..value = const IdentityProfile(
          accountId: 'a',
          name: '认证姓名',
          verificationStatus: 'VERIFIED',
        );
      await open(tester, repo);
      expect(find.text('已认证'), findsOneWidget);
      await tester.tap(find.byTooltip('编辑身份'));
      await tester.pumpAndSettle();
      final name = tester.widget<TextFormField>(
        find.byKey(const ValueKey('identity-name')),
      );
      expect(name.initialValue, '认证姓名');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('identity-name')),
                matching: find.byType(EditableText),
              ),
            )
            .readOnly,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('identity-phone')),
        '123',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入正确的手机号码'), findsOneWidget);
      expect(repo.writes, 0);
      await tester.enterText(
        find.byKey(const ValueKey('identity-phone')),
        '13800000000',
      );
      repo.failSave = true;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('身份资料保存失败，请重试'), findsOneWidget);
      expect(find.text('13800000000'), findsOneWidget);
      expect(repo.lastVerified, isTrue);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('认证姓名'), findsOneWidget);
      expect(find.text('未填写'), findsOneWidget);
    },
  );

  testWidgets(
    'delete cancel and system back never write; confirmed deletion clears profile',
    (tester) async {
      final repo = _Repository()
        ..value = const IdentityProfile(accountId: 'a', name: '测试姓名');
      await open(tester, repo);
      await tester.tap(find.byTooltip('删除身份'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(repo.deletes, 0);
      await tester.tap(find.byTooltip('删除身份'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('我的身份'), findsOneWidget);
      expect(repo.deletes, 0);
      await tester.tap(find.byTooltip('删除身份'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除身份'));
      await tester.pumpAndSettle();
      expect(repo.deletes, 1);
      expect(repo.deletedEffects, 1);
      expect(find.text('身份已删除，已切换为默认音色'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('暂无身份信息'), findsOneWidget);
      expect(find.text('声音克隆'), findsNothing);
    },
  );

  testWidgets('small portrait large text supports editing and explicit back', (
    tester,
  ) async {
    final repo = _Repository();
    await open(tester, repo, size: const Size(320, 568), textScale: 1.4);
    await tester.tap(find.text('填写身份信息'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('identity-name')), '测试');
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('暂无身份信息'), findsOneWidget);
    expect(repo.writes, 0);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('设置入口'), findsOneWidget);
  });
  testWidgets('verified long identity stays readable on small portrait', (
    tester,
  ) async {
    final repo = _Repository()
      ..value = const IdentityProfile(
        accountId: 'a',
        name: '测试姓名较长用于验证资料换行而不会超出屏幕',
        contactPhone: '13800000000',
        verificationStatus: 'VERIFIED',
      );
    await open(tester, repo, size: const Size(320, 568), textScale: 1.4);
    await tester.ensureVisible(find.text('声音克隆'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('已认证'), findsOneWidget);
  });
}

class _Repository implements IdentityRepository {
  IdentityProfile value = const IdentityProfile(accountId: 'a');
  bool failLoad = false, failSave = false, lastVerified = false;
  int writes = 0, deletes = 0;
  int deletedEffects = 0;
  @override
  Future<IdentityProfile> load() async {
    if (failLoad) throw StateError('synthetic');
    return value;
  }

  @override
  Future<IdentityProfile> save(
    IdentityDraft draft, {
    required bool verified,
  }) async {
    writes++;
    lastVerified = verified;
    if (failSave) throw StateError('synthetic');
    return value = IdentityProfile(
      accountId: 'a',
      name: draft.name,
      gender: draft.gender,
      contactPhone: draft.contactPhone,
      verificationStatus: verified ? 'VERIFIED' : '',
    );
  }

  @override
  Future<IdentityProfile> delete() async {
    deletes++;
    return value = const IdentityProfile(accountId: 'a');
  }
}
