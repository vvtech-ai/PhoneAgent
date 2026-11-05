import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/features/identity/presentation/pages/identity_cleanup_preview_page.dart';

void main() {
  testWidgets('formal page retries only local work within isolated preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWith(
            (_) => throw StateError('Real account escape'),
          ),
          identityDeletedEffectProvider.overrideWith(
            (_) => throw StateError('Real storage escape'),
          ),
        ],
        child: const MaterialApp(home: IdentityCleanupPreviewPage()),
      ),
    );
    await tester.tap(find.text('打开合成身份'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除身份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除身份').last);
    await tester.pumpAndSettle();
    expect(find.text('暂无身份信息'), findsOneWidget);
    expect(find.text('重试本地处理'), findsOneWidget);
    expect(find.text('身份已删除，已切换为默认音色'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.tap(find.text('重试本地处理'));
    await tester.pumpAndSettle();
    expect(find.text('重试本地处理'), findsNothing);
    expect(find.text('身份已删除，已切换为默认音色'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('模拟服务端删除：1 次'), findsOneWidget);
    expect(find.text('模拟跳过偏好保存：1 次'), findsOneWidget);
    expect(find.text('模拟录音清理尝试：2 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
