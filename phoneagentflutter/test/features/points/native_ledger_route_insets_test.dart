import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/core/design/native_page_header.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'package:phone_agent/features/points/presentation/pages/points_wallet_route.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('ledger full body and safe last action $platform $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<PointsLedgerPage>();
        final repo = PointsRepositoryFake()..ledgerPending = pending;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pointsWalletRepositoryProvider.overrideWithValue(repo),
              pointsWalletCacheProvider.overrideWithValue(
                const EmptyPointsWalletCache(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(
                  padding: const EdgeInsets.only(top: 24, bottom: 48),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const PointsWalletRoute(ledger: true),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final top = tester.getBottomLeft(find.byType(NativePageHeader)).dy;
        expect(
          tester.getCenter(find.byType(CircularProgressIndicator)).dy,
          closeTo((top + 568) / 2, 1),
        );
        pending.complete(
          PointsLedgerPage(
            items: List.generate(20, (i) => pointsRow(i + 1)),
            page: 0,
            size: 20,
            totalElements: 60,
            totalPages: 3,
          ),
        );
        await tester.pumpAndSettle();
        final card = find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.child is ListView,
          ),
        );
        expect(tester.getBottomLeft(card).dy, 568);
        await tester.scrollUntilVisible(find.text('加载更多'), 300);
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        final more = find.widgetWithText(TextButton, '加载更多');
        expect(tester.getBottomLeft(more).dy, lessThanOrEqualTo(568 - 48 - 24));
        expect(more.hitTestable(), findsOneWidget);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(repo.pages, [0, 1]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
