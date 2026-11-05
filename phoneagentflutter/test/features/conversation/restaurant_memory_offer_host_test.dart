import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/context/restaurant_contact_memory_offer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/restaurant_memory_offer_host.dart';
import 'restaurant_contact_memory_offer_test.dart' show AskedStore;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform only current foreground displayed question is marked',
      (tester) async {
        final store = AskedStore();
        var current = true;
        final offer = RestaurantContactMemoryOffer(store, () => current);
        final hasOffer = ValueNotifier(false);
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            theme: ThemeData(platform: platform),
            home: ValueListenableBuilder(
              valueListenable: hasOffer,
              builder: (_, value, __) => RestaurantMemoryOfferHost(
                hasOffer: value,
                isCurrent: () => current,
                onShown: offer.shown,
                child: const Scaffold(
                  body: Text('要不要记住这位预订人的姓名和手机号？下次订餐可以直接使用。'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('覆盖页')),
          ),
        );
        await tester.pumpAndSettle();
        hasOffer.value = true;
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(store.writes, 1);
        current = false;
        hasOffer.value = false;
        await tester.pumpAndSettle();
        hasOffer.value = true;
        await tester.pumpAndSettle();
        expect(store.writes, 1);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        await tester.pumpWidget(const SizedBox());
        offer.close();
        hasOffer.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
