import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/feedback_providers.dart';
import 'package:phone_agent/app/mobile_preview.dart';
import 'package:phone_agent/app/task_rating_providers.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/presentation/controller/task_rating_controller.dart';
import 'package:phone_agent/features/feedback/presentation/pages/call_evaluation_route.dart';
import 'feedback_preview_ports.dart';

const _target = FeedbackTarget(FeedbackTargetKind.call, 'mock-call');
void main() {
  if (!kDebugMode) throw UnsupportedError('Preview is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MobilePreview(child: child!),
      home: const FeedbackPreviewPage(),
    ),
  );
}

class FeedbackPreviewPage extends StatefulWidget {
  const FeedbackPreviewPage({super.key});

  @override
  State<FeedbackPreviewPage> createState() => _FeedbackPreviewPageState();
}

class _FeedbackPreviewPageState extends State<FeedbackPreviewPage> {
  final repository = PreviewTaskRatingRepository();
  final drafts = PreviewRatingDraftStore();
  final evaluation = PreviewEvaluationRepository();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      callEvaluationRepositoryProvider.overrideWithValue(evaluation),
      taskRatingControllerProvider(_target).overrideWith((ref) {
        final controller = TaskRatingController(
          target: _target,
          repository: repository,
          drafts: drafts,
          clientVersion: '1.0.0',
        );
        controller.load();
        return controller;
      }),
    ],
    child: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              '评价交互演练 · MOCK',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('合成数据、内存草稿；不访问账号、不写评价、不发积分。\n首次提交故意失败，点击重试可继续成功/只读流程。'),
            SizedBox(height: 20),
            CallEvaluationRoute(target: _target),
          ],
        ),
      ),
    ),
  );
}
