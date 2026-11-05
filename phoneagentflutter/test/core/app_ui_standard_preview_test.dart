import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/memory_providers.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/memory/domain/account_memory.dart';
import 'package:phone_agent/features/memory/presentation/pages/memory_editor_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_payment.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_text_bubble.dart';
import '../features/memory/memory_pages_test.dart' show Repository;
import '../support/pump_ui_transitions.dart';

void main() {
  for (final page in ['home', 'memory', 'payment', 'conversation']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$page full-page local preview at $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final font = Platform.environment['UI_BATCH2_PREVIEW_FONT'];
        if (font != null) {
          await tester.runAsync(() async {
            final loader = FontLoader('UiPreview');
            loader.addFont(File(font).readAsBytes().then(ByteData.sublistView));
            await loader.load();
          });
        }
        for (final entry in {
          'MaterialIcons': Platform.environment['UI_BATCH2_ICON_FONT'],
          'UiLatin': Platform.environment['UI_BATCH2_LATIN_FONT'],
        }.entries) {
          if (entry.value == null) continue;
          await tester.runAsync(() async {
            final loader = FontLoader(entry.key);
            loader.addFont(File(entry.value!).readAsBytes().then(ByteData.sublistView));
            await loader.load();
          });
        }
        final original = MemoryEntry(
          id: 'synthetic',
          content: '这是用于布局检查的合成记忆。',
          scope: MemoryScope.all,
          skillIds: [],
        );
        final repository = Repository()..entries.add(original);
        final screen = switch (page) {
          'home' => Scaffold(
            body: NativePageBackground(
              child: SafeArea(
                child: HomePage(
                  state: const HomeState(),
                  modelName: '合成模型',
                  onModels: () {},
                  onEntry: (_) {},
                  onRefresh: () async {},
                ),
              ),
            ),
          ),
          'memory' => MemoryEditorPage(entry: original),
          'payment' => CommerceScaffold(
            title: '会员购买',
            onBack: () {},
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const CommerceCard(child: Text('合成会员信息，仅用于布局核对')),
                const SizedBox(height: 24),
                MembershipConfirmationPayment(
                  apple: false,
                  available: true,
                  selected: true,
                  accepted: true,
                  submitting: false,
                  onSelect: () {},
                  onCancel: () {},
                  onConfirm: () {},
                ),
              ],
            ),
          ),
          _ => Scaffold(
            body: NativeConversationBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    ConversationHeader(onClose: () {}, status: '请补充任务信息'),
                    const Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            NativeConversationTextBubble(
                              text: '帮我安排一项合成任务。',
                              user: true,
                            ),
                            NativeConversationTextBubble(
                              text: '请告诉我具体内容，我会先和你确认。',
                            ),
                          ],
                        ),
                      ),
                    ),
                    ConversationComposer(
                      voiceMode: false,
                      canSend: true,
                      modelName: '合成模型',
                      onToggle: () {},
                      onSend: (_) => false,
                      onNotice: (_) {},
                      onModels: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginEpochProvider.overrideWithValue(7),
              memoryRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                fontFamily: font == null ? null : 'UiPreview',
              fontFamilyFallback: font == null ? null : const ['UiLatin'],
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF0A84FF),
                ),
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, 844),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(
                  key: const Key('preview'),
                  child: screen,
                ),
              ),
            ),
          ),
        );
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
        final output = Platform.environment['UI_BATCH2_PREVIEW_DIR'];
        if (output != null) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('preview')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/$page-${scale.toInt()}x.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    }
  }
}
