import 'package:phone_agent/app/translation_access_providers.dart';
import 'package:phone_agent/app/translation_providers.dart';
import 'package:phone_agent/app/dial_permission_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/app/dial_contact_providers.dart';
import 'package:phone_agent/features/translation/data/preview_translation_configuration.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_permission_port.dart';
import 'package:phone_agent/features/dialer/domain/dial_permission.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_recent_source.dart';
import 'package:phone_agent/features/dialer/data/preview_dial_contacts.dart';
import 'package:phone_agent/features/dialer/data/system_dialer_channel.dart';
import 'package:phone_agent/features/dialer/domain/dial_recent_call.dart';
import 'package:phone_agent/features/dialer/domain/dial_contact_suggestion.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_contacts_controller.dart';
import 'package:phone_agent/features/dialer/presentation/controller/dial_recent_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_dialer_route.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/translation_location_providers.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_location_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_route.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_dial_summary.dart';

class PendingLocation
    implements TranslationLocationStore, TranslationLocationSource {
  final pending = Completer<TrustedTranslationLocation?>();
  int requests = 0;
  @override
  Future<TrustedTranslationLocation?> read() => pending.future;
  @override
  Future<void> write(TrustedTranslationLocation value) async {}
  @override
  Future<TranslationLocationResult> locate() async {
    requests++;
    return const TranslationLocationResult(TranslationLocationStatus.failed);
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> openSettings() async {}
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final outcome in ['CN', 'US', 'empty', 'failure']) {
      testWidgets('$platform pending location then $outcome and reentry', (
        tester,
      ) async {
        final location = PendingLocation();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              translationPreferenceStoreProvider.overrideWithValue(
                PreviewTranslationPreferenceStore(),
              ),
              translationBillingRepositoryProvider.overrideWithValue(
                PreviewTranslationBilling(),
              ),
              dialPermissionPortProvider.overrideWithValue(
                PreviewDialPermissionPort(allowLocation: true)
                  ..grant = DialPermissionGrant.granted,
              ),
              dialPermissionMemoryProvider.overrideWithValue(
                DialPermissionMemory()..locationShown = true,
              ),
              dialContactsProvider.overrideWith((_) {
                final c = DialContactsController(
                  PreviewDialContacts(),
                  const DialSuggestionPolicy(LpinyinContactDictionary()),
                );
                c.load();
                return c;
              }),
              dialRecentProvider.overrideWith((_) {
                final c = DialRecentController(
                  const PreviewDialRecentSource(DialRecentSource.system),
                  const PreviewDialRecentSource(DialRecentSource.app),
                );
                c.load();
                return c;
              }),
              translationLocationProvider.overrideWith((_) {
                final controller = TranslationLocationController(
                  location,
                  location,
                );
                controller.load();
                return controller;
              }),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => TranslationDialerRoute(
                          number: '2025550101',
                          translationEntry: true,
                          systemDialer: PreviewSystemDialer(),
                        ),
                      ),
                    ),
                    child: const Text('进入共享翻译拨号页'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> press(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        await press(find.text('进入共享翻译拨号页'));
        expect(find.textContaining('位置待确认'), findsNothing);
        expect(find.byType(NativeTranslationDialSummary), findsOneWidget);
        expect(
          tester
              .widget<NativeTranslationDialSummary>(
                find.byType(NativeTranslationDialSummary),
              )
              .model,
          '',
        );
        await press(find.byKey(const Key('dial-call')));
        expect(find.byType(TranslationSessionRoute), findsNothing);
        expect(find.textContaining('位置待确认'), findsNothing);
        if (outcome == 'failure') {
          location.pending.completeError(
            StateError('synthetic cache read failure'),
          );
        } else {
          location.pending.complete(
            outcome == 'empty' ? null : TrustedTranslationLocation(outcome, 1),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('位置待确认，请在国家和地区中获取当前位置'), findsNothing);
        if (outcome == 'empty' || outcome == 'failure') {
          expect(find.text('位置待确认'), findsOneWidget);
        } else {
          expect(find.text('位置待确认'), findsNothing);
          expect(find.bySemanticsLabel(RegExp('翻译模型：.+')), findsOneWidget);
        }
        await press(find.byKey(const Key('dial-close')));
        await press(find.text('进入共享翻译拨号页'));
        expect(find.text('位置待确认，请在国家和地区中获取当前位置'), findsNothing);
        // Existing permission-ready refresh runs once per entry; no OS permission request.
        expect(location.requests, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
