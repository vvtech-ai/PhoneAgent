import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  test('scene IDs are unique and every entry states its boundary', () {
    expect(
      workbenchScenes.map((s) => s.id).toSet().length,
      workbenchScenes.length,
    );
    expect(
      workbenchScenes.every((s) => s.boundary.isNotEmpty && s.group.isNotEmpty),
      isTrue,
    );
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('root dialog keeps exit and resets at $width', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [
              WorkbenchScene(
                'dialog',
                '测试',
                '根弹窗',
                '合成',
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(title: Text('合成成功')),
                    ),
                    child: const Text('打开根弹窗'),
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.tap(find.byKey(const ValueKey('scene-dialog')));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.text('打开根弹窗'));
        await tester.pumpUntilUiSettled();
        expect(find.text('合成成功'), findsOneWidget);
        expect(
          tester.semantics.simulatedAccessibilityTraversal().map(
            (n) => n.label,
          ),
          contains('返回目录'),
        );
        await tester.tap(find.byKey(const ValueKey('workbench-home')));
        await tester.pumpUntilUiSettled();
        expect(find.text('合成成功'), findsNothing);
        expect(find.byKey(const ValueKey('workbench-catalog')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('scene-dialog')));
        await tester.pumpUntilUiSettled();
        expect(find.text('合成成功'), findsNothing);
        expect(find.text('打开根弹窗'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('catalog search, nested return and fresh state at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var disposed = 0;
      final scene = WorkbenchScene(
        'counter',
        '测试',
        '计数器',
        '仅内存',
        (_) => _Counter(onDispose: () => disposed++),
      );
      await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
      await tester.enterText(
        find.byKey(const ValueKey('workbench-search')),
        '不存在',
      );
      await tester.pump();
      expect(find.text('没有匹配场景，请修改搜索内容'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('workbench-search')),
        '计数',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scene-counter')));
      await tester.pumpUntilUiSettled();
      await tester.tap(find.text('计数 0'));
      await tester.pump();
      await tester.tap(find.text('进入子页'));
      await tester.pumpUntilUiSettled();
      expect(find.text('测试子页'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workbench-home')));
      await tester.pumpUntilUiSettled();
      expect(disposed, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('workbench-search')))
            .controller!
            .text,
        '计数',
        reason: 'returning must not show an empty field with a retained filter',
      );
      await tester.tap(find.byKey(const ValueKey('scene-counter')));
      await tester.pumpUntilUiSettled();
      expect(find.text('计数 0'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpUntilUiSettled();
      expect(find.byKey(const ValueKey('workbench-catalog')), findsOneWidget);
      expect(disposed, 2);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scene in workbenchScenes) {
    testWidgets('registered scene mounts and leaves: ${scene.id}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
        await tester.ensureVisible(find.byKey(ValueKey('scene-${scene.id}')));
        await tester.tap(find.byKey(ValueKey('scene-${scene.id}')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('workbench-home')), findsOneWidget);
        expect(
          tester.semantics.simulatedAccessibilityTraversal().map(
            (node) => node.label,
          ),
          contains('返回目录'),
          reason: 'nested routes must not hide the persistent escape action',
        );
        await tester.tap(find.byKey(const ValueKey('workbench-home')));
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}

class _Counter extends StatefulWidget {
  const _Counter({required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => setState(() => count++),
          child: Text('计数 $count'),
        ),
        TextButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('测试子页')),
            ),
          ),
          child: const Text('进入子页'),
        ),
      ],
    ),
  );
}
