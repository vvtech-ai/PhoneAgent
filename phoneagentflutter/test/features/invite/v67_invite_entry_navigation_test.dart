import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/core/design/native_page_header.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/presentation/widgets/home_hero.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';
import 'package:phone_agent/features/invite/domain/invite_entry_presentation.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_activity_route.dart';
import 'invite_fakes.dart';

void main() {
  for (final source in ['福利', '邀请好友']) {
    testWidgets('v67 $source entry returns to its actual source', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inviteRepositoryProvider.overrideWithValue(FakeInviteRepository()),
            inviteDeviceProvider.overrideWithValue(FakeInviteDevice()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                void open() => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InviteActivityRoute(title: source),
                  ),
                );
                return Scaffold(
                  body: source == '福利'
                      ? HomeHero(
                          slogan: const HomeSlogan('s', '任务', '说明'),
                          modelName: '合成模型',
                          onModels: () {},
                          onWelfare: open,
                        )
                      : SettingsPage(
                          developer: false,
                          modelSummary: '合成模型',
                          originalSummary: '设置',
                          inviteEntry: const InviteEntryPresentation(
                            true,
                            '以活动规则为准',
                          ),
                          onOpen: (destination) {
                            if (destination == SettingsDestination.invite) {
                              open();
                            }
                          },
                        ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        source == '福利' ? find.byTooltip('福利') : find.text('邀请好友'),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(NativePageHeader),
          matching: find.text(source),
        ),
        findsOneWidget,
      );
      expect(find.text('邀请记录'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(
        source == '福利' ? find.byTooltip('福利') : find.text('设置'),
        findsOneWidget,
      );
    });
  }
  testWidgets('missing activity hides both invite entries', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HomeHero(
                slogan: const HomeSlogan('s', '任务', '说明'),
                modelName: '合成模型',
                onModels: () {},
              ),
              Expanded(
                child: SettingsPage(
                  developer: false,
                  modelSummary: '',
                  originalSummary: '',
                  onOpen: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byTooltip('福利'), findsNothing);
    expect(find.text('邀请好友'), findsNothing);
  });
}
