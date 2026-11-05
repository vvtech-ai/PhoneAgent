import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/contacts/presentation/controller/contacts_controller.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contacts_page.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/tasks/presentation/pages/tasks_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final title in ['联系人', '任务', '设置']) {
          testWidgets('$platform $width $scale ordinary title $title', (
            tester,
          ) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 820);
            addTearDown(tester.view.reset);
            final font = Platform.environment['UI_TITLE_PREVIEW_FONT'];
            if (font != null) {
              await tester.runAsync(() async {
                final loader = FontLoader('TitlePreview');
                loader.addFont(
                  File(font).readAsBytes().then(ByteData.sublistView),
                );
                await loader.load();
              });
            }
            final page = switch (title) {
              '联系人' => ContactsPage(
                state: const ContactsState(),
                onRefresh: () async {},
                onRequestPermission: () {},
                onOpen: (_) {},
              ),
              '任务' => TasksPage(
                state: const TaskState(),
                onRefresh: () async {},
                onOpen: (_) {},
              ),
              _ => SettingsPage(
                developer: false,
                modelSummary: '默认模型',
                originalSummary: '设置',
                onOpen: (_) {},
              ),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  platform: platform,
                  fontFamily: font == null ? null : 'TitlePreview',
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF0A84FF),
                  ),
                ),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: Scaffold(body: NativePageBackground(child: page)),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.text(title));
            expect(rect.left, 46);
            expect(rect.height, scale == 1 ? 40 : 80);
            expect(find.byTooltip('返回'), findsNothing);
            expect(tester.takeException(), isNull);
            final output = Platform.environment['UI_TITLE_PREVIEW_DIR'];
            if (output != null &&
                width == 390 &&
                platform == TargetPlatform.iOS) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('preview')),
              );
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(output).create(recursive: true);
                final name = switch (title) {
                  '联系人' => 'contacts',
                  '任务' => 'tasks',
                  _ => 'settings',
                };
                await File(
                  '$output/$name-${scale.toInt()}x.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          });
        }
      }
    }
  }
}
