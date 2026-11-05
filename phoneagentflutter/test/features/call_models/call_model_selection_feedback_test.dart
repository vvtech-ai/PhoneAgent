import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/widgets/call_model_selection_feedback.dart';

class _Repository implements CallModelRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends CallModelController {
  _Controller() : super(_Repository());
  var success = true;
  var selections = 0;
  VoidCallback? completing;
  @override
  Future<bool> select(CallModel model) async {
    selections++;
    completing?.call();
    if (success) {
      state = state.copy(catalog: CallModelCatalog(model.id, [model]));
    }
    return success;
  }
}

void main() {
  const model = CallModel(
    id: 'DOUBAO',
    name: 'Seeduplex',
    description: '',
    available: true,
    active: false,
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform switch feedback respects results and ownership', (
      tester,
    ) async {
      final controller = _Controller();
      var current = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => selectCallModelWithFeedback(
                context,
                controller,
                model,
                isCurrent: () => current,
                readState: () => controller.state,
              ),
              child: const Text('切换'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('切换'));
      await tester.pump();
      expect(find.text('通话模型已切换为 Seeduplex'), findsOneWidget);
      dismissNativeNotice();
      await tester.pump();
      await tester.tap(find.text('切换'));
      await tester.pump();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      controller.dispose();
    });
    testWidgets('$platform failed and stale switch feedback', (tester) async {
      final controller = _Controller()..success = false;
      var current = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => selectCallModelWithFeedback(
                context,
                controller,
                model,
                isCurrent: () => current,
                readState: () => controller.state,
              ),
              child: const Text('切换'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('切换'));
      await tester.pump();
      expect(find.text('通话模型切换失败，请检查网络或本地服务连接'), findsOneWidget);
      dismissNativeNotice();
      await tester.pump();
      controller.completing = () => current = false;
      await tester.tap(find.text('切换'));
      await tester.pump();
      expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
      controller.dispose();
    });
  }
}
