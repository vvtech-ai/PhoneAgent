import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../data/preview_clone_creation_port.dart';
import '../../domain/clone_creation.dart';
import '../widgets/clone_creation_sheet.dart';
import 'clone_enrollment_page.dart';

class CloneCreationPreviewPage extends StatefulWidget {
  const CloneCreationPreviewPage({super.key, required this.scenario});
  final CloneCreationScenario scenario;
  @override
  State<CloneCreationPreviewPage> createState() =>
      _CloneCreationPreviewPageState();
}

class _CloneCreationPreviewPageState extends State<CloneCreationPreviewPage> {
  late final _port = PreviewCloneCreationPort(widget.scenario);
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final launch = await showCloneCreationSheet(context, _port);
    if (!mounted) return;
    if (launch != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CloneEnrollmentPreviewPage(
            port: PreviewCloneCreationEnrollmentPort(widget.scenario),
            modelName: launch.model.name,
            start: launch.start,
            reuseOnRerecord:
                launch.start == CloneCreationStart.savedRecording ||
                (launch.start == CloneCreationStart.existingCandidate &&
                    launch.model.candidateFromRecording),
          ),
        ),
      );
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('创建克隆入口演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 模型选择与认证录音复用', style: ShellTokens.cardTitle),
          const SizedBox(height: 14),
          const Text(
            '使用合成模型、积分和录音状态，不读取真实文件、不修改真实身份或音色。',
            style: ShellTokens.subtitle,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _opening ? null : _open,
            child: const Text('选择声音克隆模型'),
          ),
        ],
      ),
    ),
  );
}
