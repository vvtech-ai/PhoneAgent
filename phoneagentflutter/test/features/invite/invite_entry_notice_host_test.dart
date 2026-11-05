import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_entry_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_reward_host.dart';
import 'invite_fakes.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final cold in [true, false]) {
      testWidgets('global builder invitation notice $platform cold=$cold', (
        tester,
      ) async {
        final navigator = GlobalKey<NavigatorState>();
        final pending = PendingInviteController(MemoryInviteStore());
        await pending.initialize();
        final device = FakeInviteDevice();
        final entry = InviteEntryController(
          device,
          const InviteLinkPolicy(
            host: 'example.test',
            path: '/invite/',
            scheme: 'phoneagent-test',
          ),
          pending,
        );
        addTearDown(pending.dispose);
        addTearDown(device.received.close);
        addTearDown(dismissNativeNotice);
        await entry.start();
        if (cold) {
          entry.receive('https://example.test/invite/?code=ABCD');
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [inviteEntryProvider.overrideWith((_) => entry)],
            child: MaterialApp(
              navigatorKey: navigator,
              theme: ThemeData(platform: platform),
              builder: (_, child) =>
                  InviteEntryHost(navigatorKey: navigator, child: child!),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: Text('合成详情')),
                      ),
                    ),
                    child: const Text('查看详情'),
                  ),
                ),
              ),
            ),
          ),
        );
        entry.session(ready: true, signedIn: true);
        if (!cold) {
          device.received.add('https://example.test/invite/?code=ABCD');
        }
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('本次邀请奖励仅限新用户'), findsOneWidget);
        expect(pending.state.code, isEmpty);
        await tester.tap(find.text('查看详情'));
        await tester.pumpAndSettle();
        expect(find.text('合成详情'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
