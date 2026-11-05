import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_route.dart';

Future<void> _open(WidgetTester tester, _Repository repo, double scale) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [identityRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
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
  );
  await tester.tap(find.text('设置入口'));
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'header and system back discard draft at scale $scale',
      (tester) async {
        final repo = _Repository();
        await _open(tester, repo, scale);
        await tester.tap(find.byTooltip('编辑身份'));
        await tester.pumpAndSettle();
        expect(find.text('取消'), findsNothing);
        expect(find.text('姓名 *', findRichText: true), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('identity-name')),
          '未保存草稿',
        );
        tester.testTextInput.hide();
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(IdentityRoute), findsOneWidget);
        expect(find.text('演练用户'), findsOneWidget);
        expect(find.text('未保存草稿'), findsNothing);
        expect(repo.writes, 0);
        await tester.tap(find.byTooltip('编辑身份'));
        await tester.pumpAndSettle();
        expect(find.text('演练用户'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('identity-name')),
          '另一份草稿',
        );
        tester.testTextInput.hide();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(IdentityRoute), findsOneWidget);
        expect(find.text('演练用户'), findsOneWidget);
        expect(repo.writes, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(IdentityRoute), findsNothing);
        expect(find.text('设置入口'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  testWidgets(
    'verified name cannot focus and pending save blocks both backs',
    (tester) async {
      final repo = _Repository(verified: true);
      await _open(tester, repo, 2);
      await tester.tap(find.byTooltip('编辑身份'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('identity-name'));
      expect(tester.widget<TextFormField>(name).enabled, isFalse);
      await tester.tap(name);
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(of: name, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('identity-phone')));
      await tester.enterText(
        find.byKey(const ValueKey('identity-phone')),
        '13800000000',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(repo.writes, 1);
      expect(repo.lastDraft!.name, '演练用户');
      await tester.tap(find.byTooltip('返回'));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(IdentityRoute), findsOneWidget);
      expect(find.byKey(const ValueKey('identity-phone')), findsOneWidget);
      repo.pending.completeError(StateError('synthetic failure'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(IdentityRoute), findsOneWidget);
      expect(find.text('未填写'), findsOneWidget);
      expect(find.text('身份资料保存失败，请重试'), findsNothing);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.byType(IdentityRoute), findsNothing);
      expect(repo.writes, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}

class _Repository implements IdentityRepository {
  _Repository({this.verified = false});
  final bool verified;
  int writes = 0;
  IdentityDraft? lastDraft;
  final pending = Completer<IdentityProfile>();
  @override
  Future<IdentityProfile> load() async => IdentityProfile(
    accountId: 'synthetic',
    name: '演练用户',
    gender: '不透露',
    verificationStatus: verified ? 'VERIFIED' : '',
  );
  @override
  Future<IdentityProfile> save(IdentityDraft draft, {required bool verified}) {
    writes++;
    lastDraft = draft;
    return pending.future;
  }

  @override
  Future<IdentityProfile> delete() => throw StateError('Deletion is forbidden');
}
