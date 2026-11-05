import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_navigation_backdrop.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/shell/presentation/widgets/floating_navigation.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in ['home', 'contacts', 'tasks', 'settings']) {
        testWidgets(
          '$page backdrop width=$width scale=$scale last item reachable',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final font = Platform.environment['UI_BATCH2_PREVIEW_FONT'];
            if (font != null) {
              await tester.runAsync(() async {
                for (final entry in {
                  'UiPreview': font,
                  'MaterialIcons': Platform.environment['UI_BATCH2_ICON_FONT'],
                  'UiLatin': Platform.environment['UI_BATCH2_LATIN_FONT'],
                }.entries) {
                  if (entry.value == null) continue;
                  final loader = FontLoader(entry.key)
                    ..addFont(
                      File(
                        entry.value!,
                      ).readAsBytes().then(ByteData.sublistView),
                    );
                  await loader.load();
                }
              });
            }
            final home = const HomeState();
            final homeCards = home.config.cards
                .where(
                  (c) =>
                      c.status != HomeCardStatus.disabled && c.defaultVisible,
                )
                .toList();
            final contacts = List.generate(
              20,
              (i) => ContactRecord(
                name: '合成联系人$i',
                phone: '20255501${i.toString().padLeft(2, '0')}',
                systemDialPhone: '20255501${i.toString().padLeft(2, '0')}',
              ),
            );
            final tasks = List.generate(
              20,
              (i) => TaskRecord(
                id: '$i',
                kind: TaskRecordKind.conversation,
                title: '合成任务$i',
                status: TaskStatus.completed,
                rawStatus: 'completed',
              ),
            );
            final screen = switch (page) {
              'home' => HomePage(
                state: home,
                modelName: '合成模型',
                onModels: () {},
                onEntry: (_) {},
                onRefresh: () async {},
              ),
              'contacts' => ContactsPage(
                state: ContactsState(
                  contacts: contacts,
                  access: ContactAccess.authorized,
                ),
                onOpen: (_) {},
                onRefresh: () async {},
                onRequestPermission: () {},
              ),
              'tasks' => TasksPage(
                state: TaskState(catalog: TaskCatalog(tasks)),
                onOpen: (_) {},
                onRefresh: () async {},
              ),
              _ => SettingsPage(
                developer: true,
                modelSummary: '合成模型',
                originalSummary: '设置',
                onOpen: (_) {},
              ),
            };
            var selections = 0, dials = 0;
            double inset = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  fontFamily: font == null ? null : 'UiPreview',
                  fontFamilyFallback: font == null ? null : const ['UiLatin'],
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: RepaintBoundary(
                      key: const Key('navigation-preview'),
                      child: NativePageBackground(
                        child: Builder(
                          builder: (context) {
                            inset = FloatingNavigation.contentInset(context);
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: NativeNavigationBackdrop(
                                    contentInset: inset,
                                    child: screen,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: FloatingNavigation(
                                    selected: 0,
                                    onSelected: (_) => selections++,
                                    onDial: () => dials++,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey('navigation-background-wash')),
              findsOneWidget,
            );
            expect(
              find.ancestor(
                of: find.byType(FloatingNavigation),
                matching: find.byType(BackdropFilter),
              ),
              findsNothing,
            );
            Future<void> capture(String suffix) async {
              final output = Platform.environment['NAVIGATION_PREVIEW_DIR'];
              if (output == null || width != 390) return;
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('navigation-preview')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(output).create(recursive: true);
                await File(
                  '$output/$page-${scale.toInt()}x-$suffix.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }

            await capture('first');
            final scroll = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            final last = switch (page) {
              'home' =>
                find
                    .ancestor(
                      of: find.text(homeCards.last.title),
                      matching: find.byType(Container),
                    )
                    .first,
              'contacts' => find.byKey(
                ValueKey(
                  'contact-row-${contacts.last.name}-${contacts.last.key}',
                ),
              ),
              'tasks' => find.byKey(ValueKey(tasks.last.id)),
              _ => find.byKey(const Key('settings-logout')),
            };
            final rect = tester.getRect(last);
            expect(rect.top, greaterThanOrEqualTo(0));
            final clearBottom = 844 - inset;
            expect(rect.bottom, lessThanOrEqualTo(clearBottom));
            if (page == 'tasks') {
              expect(
                tester.getRect(find.text('已显示全部任务')).bottom,
                lessThanOrEqualTo(clearBottom),
              );
            }
            await capture('last');
            await tester.tap(find.byKey(const ValueKey('tab-3')));
            await tester.tap(find.byKey(const ValueKey('assistantFab')));
            expect(selections, 1);
            expect(dials, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
