import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_update/presentation/widgets/native_update_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'update notes retain multiline body and native left alignment $platform',
      (tester) async {
        const notes = '测试102002\n继续测试';
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: NativeUpdateDialog(
                title: '发现新版本',
                version: '1.0.52',
                notes: notes,
                primary: '下载中 0%',
                onPrimary: null,
                primaryKey: const Key('primary'),
                status: const Text('正在下载…'),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(notes),
        );
        expect(paragraph.text.toPlainText(), notes);
        expect(paragraph.textAlign, TextAlign.left);
        expect(paragraph.text.style?.fontSize, 14);
        expect(paragraph.text.style?.height, closeTo(20 / 14, .001));
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('新版本：1.0.52'))
              .textAlign,
          TextAlign.center,
        );
        expect(
          tester.getTopLeft(find.text(notes)).dx,
          tester.getTopLeft(find.text('新版本：1.0.52')).dx,
        );
        expect(find.text('正在下载…'), findsOneWidget);
        expect(find.text('下载中 0%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('blank update notes use native fallback $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: NativeUpdateDialog(
              title: '发现新版本',
              version: '1.0.52',
              notes: ' \n\t ',
              primary: '立即更新',
              onPrimary: () {},
              primaryKey: const Key('primary'),
            ),
          ),
        ),
      );
      expect(find.text('本次更新包含体验优化与问题修复。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
