import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/membership_model_names_provider.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'fake_commerce_repository.dart';
import 'membership_route_v2_test.dart' show V2Repository, app;

class RetryModels implements CallModelRepository {
  int reads = 0;
  @override
  Future<CallModelCatalog> load() async {
    if (++reads == 1) throw StateError('synthetic failure');
    return const CallModelCatalog('3', [
      CallModel(
        id: '3',
        name: 'Seeduplex V3',
        description: '',
        available: false,
        active: false,
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'page refresh retries failed model names including upgrade-only models',
    (tester) async {
      final models = RetryModels();
      final fixtureApp =
          app(V2Repository('new'), FakePaymentLauncher()) as ProviderScope;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...fixtureApp.overrides,
            callModelRepositoryProvider.overrideWithValue(models),
          ],
          child: fixtureApp.child,
        ),
      );
      await tester.pumpAndSettle();
      expect(models.reads, 1);
      await tester
          .widget<MembershipPage>(find.byType(MembershipPage))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(models.reads, 2);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MembershipPage)),
      );
      expect(container.read(membershipModelNamesProvider).valueOrNull, {
        '3': 'Seeduplex V3',
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
