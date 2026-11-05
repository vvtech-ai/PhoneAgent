import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/features/identity/domain/identity_profile.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_route.dart';

Future<ProviderContainer> _open(WidgetTester tester, _Repository repo) async {
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
          ).copyWith(textScaler: TextScaler.linear(2)),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return ProviderScope.containerOf(tester.element(find.byType(IdentityRoute)));
}

void main() {
  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  for (final systemBack in [false, true]) {
    testWidgets(
      'pending initial read can leave with systemBack=$systemBack',
      (tester) async {
        final repo = _Repository();
        await _open(tester, repo);
        expect(find.text('正在加载身份信息…'), findsOneWidget);
        expect(find.text('填写身份信息'), findsNothing);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byTooltip('返回'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(IdentityRoute), findsNothing);
        repo.pending.single.complete(_Repository.profile);
        await tester.pumpAndSettle();
        expect(find.text('设置入口'), findsOneWidget);
        expect(repo.reads, 1);
        expect(tester.takeException(), isNull);
      },
      variant: platforms,
    );
  }

  testWidgets(
    'initial failure retries once without premature empty editor',
    (tester) async {
      final repo = _Repository();
      await _open(tester, repo);
      repo.pending[0].completeError(StateError('synthetic read failure'));
      await tester.pumpAndSettle();
      expect(find.text('身份信息加载失败'), findsOneWidget);
      expect(find.text('填写身份信息'), findsNothing);
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(repo.reads, 2);
      expect(find.text('重试'), findsNothing);
      expect(find.text('正在加载身份信息…'), findsOneWidget);
      repo.pending[1].complete(const IdentityProfile(accountId: 'synthetic'));
      await tester.pumpAndSettle();
      expect(find.text('填写身份信息'), findsOneWidget);
      expect(find.text('身份信息加载失败'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'cached failed refresh preserves profile and explicit retry only reads',
    (tester) async {
      final repo = _Repository();
      final container = await _open(tester, repo);
      repo.pending[0].complete(_Repository.profile);
      await tester.pumpAndSettle();
      final refresh = container
          .read(identityControllerProvider.notifier)
          .load();
      await tester.pump();
      expect(find.text('演练用户'), findsOneWidget);
      repo.pending[1].completeError(StateError('synthetic refresh failure'));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('演练用户'), findsOneWidget);
      expect(find.text('身份资料加载失败，请重试'), findsOneWidget);
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(repo.reads, 3);
      expect(find.text('演练用户'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      repo.pending[2].complete(_Repository.profile);
      await tester.pumpAndSettle();
      expect(find.text('身份资料加载失败，请重试'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );
}

class _Repository implements IdentityRepository {
  static const profile = IdentityProfile(
    accountId: 'synthetic',
    name: '演练用户',
    gender: '不透露',
  );
  final pending = <Completer<IdentityProfile>>[];
  int get reads => pending.length;
  @override
  Future<IdentityProfile> load() {
    final result = Completer<IdentityProfile>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<IdentityProfile> save(IdentityDraft draft, {required bool verified}) =>
      throw StateError('Writing is forbidden');
  @override
  Future<IdentityProfile> delete() => throw StateError('Deletion is forbidden');
}
