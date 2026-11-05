import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/data/api_clone_voice_repository.dart';
import 'package:phone_agent/features/call_models/domain/clone_voice.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/native_clone_entry.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/clone_voice_card.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform main entry price and semantics follow valid/unknown quote; click remains available',
      (tester) async {
        var clicks = 0;
        final semantics = tester.ensureSemantics();
        try {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          for (final price in <int?>[650, 900, null, 0, -1]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: NativeCloneEntry(
                      pricePoints: price,
                      onTap: () => clicks++,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final known = price != null && price > 0;
            expect(find.text(known ? '$price' : '—'), findsOneWidget);
            expect(find.text('300'), findsNothing);
            final label = known ? '声音克隆，$price积分' : '声音克隆，价格暂不可用';
            expect(find.bySemanticsLabel(label), findsOneWidget);
            await tester.tap(find.bySemanticsLabel(label));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          expect(clicks, 5);
        } finally {
          semantics.dispose();
        }
      },
    );
    testWidgets(
      '$platform voice entry uses its own model price and suppresses mismatched snapshot',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var clicks = 0;
          for (final id in ['4', '7']) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: Scaffold(
                  body: CloneVoiceCard(
                    state: CallModelState(
                      voiceProvider: '4',
                      clone: CloneVoiceSnapshot(
                        modelId: id,
                        available: true,
                        currentStatus: 'NOT_CREATED',
                        currentHasAsset: false,
                        pricePoints: 850,
                      ),
                    ),
                    onSelect: () {},
                    onRefresh: () {},
                    onCreate: () => clicks++,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(id == '4' ? '850' : '—'), findsOneWidget);
            expect(find.text('300'), findsNothing);
            await tester.tap(
              find.bySemanticsLabel(id == '4' ? '声音克隆，850积分' : '声音克隆，价格暂不可用'),
            );
          }
          expect(clicks, 2);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  for (final raw in [null, 0, -1, 650, '850', 'private-invalid', []]) {
    test(
      'voice status response reuses its price without extra network: $raw',
      () async {
        final fake = SyntheticAccountApi()
          ..data = {
            'models': [
              {
                'modelId': '4',
                'available': true,
                'pricePoints': raw,
                'candidate': null,
                'current': {
                  'modelId': '4',
                  'status': 'NOT_CREATED',
                  'providerAssetId': '',
                },
              },
            ],
          };
        addTearDown(fake.api.close);
        final result = await ApiCloneVoiceRepository(fake.api).load('4');
        expect(
          result.pricePoints,
          raw == 650
              ? 650
              : raw == '850'
              ? 850
              : null,
        );
        expect(result.currentReady, false);
        expect(fake.requests, hasLength(1));
      },
    );
  }
}
