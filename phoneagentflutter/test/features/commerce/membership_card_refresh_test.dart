import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_price_options.dart';
import 'fake_commerce_repository.dart';
import 'membership_reference_fixture.dart';

class LabelRepository extends FakeCommerceRepository {
  String level = 'BASIC';
  Completer<MembershipCurrent>? gate;
  @override
  Future<CommerceCatalog> catalog() async =>
      membershipReferenceFixture('PLUS').catalog!;
  @override
  Future<MembershipCurrent> membership() async => gate?.future ?? member(level);
}

MembershipCurrent member(String level) => MembershipCurrent(
  level: level,
  currentMonths: 1,
  entitlementVersionId: 1,
  benefits: null,
  terms: const [],
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform refreshed active membership never adds relationship labels',
      (tester) async {
        final repository = LabelRepository();
        await tester.pumpWidget(host(platform, repository));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MembershipPriceOptions));
        final container = ProviderScope.containerOf(context);
        container.read(catalogControllerProvider.notifier).selectLevel('PLUS');
        await tester.pump();
        expect(find.text('升级'), findsNothing);
        expect(find.text('续购'), findsNothing);
        repository.level = 'PLUS';
        repository.gate = Completer();
        final refresh = container
            .read(catalogControllerProvider.notifier)
            .load();
        await tester.pump();
        expect(find.text('升级'), findsNothing);
        expect(find.text('续购'), findsNothing);
        repository.gate!.complete(member('PLUS'));
        await refresh;
        await tester.pumpAndSettle();
        expect(find.text('续购'), findsNothing);
        expect(find.text('升级'), findsNothing);
        expect(
          container.read(catalogControllerProvider).membership?.level,
          'PLUS',
        );
      },
    );

    testWidgets(
      '$platform late old account response cannot replace current membership or add labels',
      (tester) async {
        final epoch = StateProvider<int>((ref) => 1);
        final repository = LabelRepository()..gate = Completer();
        final old = repository.gate!;
        await tester.pumpWidget(host(platform, repository, epoch: epoch));
        await tester.pumpAndSettle();
        expect(find.text('升级'), findsNothing);
        expect(find.text('续购'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MembershipPriceOptions)),
        );
        repository.gate = null;
        repository.level = 'PLUS';
        container.read(epoch.notifier).state = 2;
        await tester.pumpAndSettle();
        expect(find.text('续购'), findsNothing);
        old.complete(member('BASIC'));
        await tester.pumpAndSettle();
        expect(find.text('续购'), findsNothing);
        expect(find.text('升级'), findsNothing);
        expect(
          container.read(catalogControllerProvider).membership?.level,
          'PLUS',
        );
      },
    );
  }
}

Widget host(
  TargetPlatform platform,
  LabelRepository repository, {
  StateProvider<int>? epoch,
}) => ProviderScope(
  overrides: [
    loginEpochProvider.overrideWith(
      (ref) => epoch == null ? 1 : ref.watch(epoch),
    ),
    commerceRepositoryProvider.overrideWithValue(repository),
    paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
    commerceDiagnosticsProvider.overrideWithValue(null),
  ],
  child: MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(catalogControllerProvider);
          return MembershipPriceOptions(state: state, onMonths: (_) {});
        },
      ),
    ),
  ),
);
