import 'package:flutter/material.dart';
import '../../../../core/design/native_page_header.dart';
import '../../domain/clone_enrollment.dart';

String cloneStepTitle(CloneStep step) => switch (step) {
  CloneStep.consent => '身份认证',
  CloneStep.identity => '1/3 填写信息',
  CloneStep.collecting || CloneStep.checking => '2/3 人脸与声音',
  CloneStep.generating => '3/3 声音克隆',
  CloneStep.candidate || CloneStep.candidateError => '我的声音克隆',
  CloneStep.confirmed => '3/3 完成',
};

class CloneFlowHeader extends StatelessWidget {
  const CloneFlowHeader({
    super.key,
    required this.step,
    required this.onBack,
    this.onResetIdentity,
  });
  final CloneStep step;
  final VoidCallback? onBack, onResetIdentity;
  @override
  Widget build(BuildContext context) => NativePageHeader(
    title: cloneStepTitle(step),
    onBack: onBack,
    trailing: onResetIdentity == null
        ? null
        : TextButton(onPressed: onResetIdentity, child: const Text('重置身份')),
  );
}
