import 'package:flutter/material.dart';
import '../../../../core/design/shell_tokens.dart';
import '../../data/preview_clone_enrollment_port.dart';
import 'clone_enrollment_page.dart';
import 'clone_management_preview_page.dart';
import '../../data/preview_clone_creation_port.dart';
import 'clone_creation_preview_page.dart';
import '../../data/preview_clone_flow.dart';
import 'clone_flow_preview_page.dart';

class ClonePreviewScenariosPage extends StatelessWidget {
  const ClonePreviewScenariosPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('声音克隆演练')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('MOCK · 不读取当前账号身份或克隆数据', style: ShellTokens.subtitle),
          for (final scenario in CloneFlowScenario.values)
            ListTile(
              title: Text(switch (scenario) {
                CloneFlowScenario.success => '正式流程装配：认证到确认',
                CloneFlowScenario.verificationSync => '正式流程装配：认证只读同步',
                CloneFlowScenario.generationUnknown => '正式流程装配：生成结果未知',
                CloneFlowScenario.confirmationUnknown => '正式流程装配：确认结果未知',
                CloneFlowScenario.saveFailure => '正式流程装配：录音保存失败',
                CloneFlowScenario.expiredRecording => '正式流程装配：录音失效',
              }),
              subtitle: const Text('与正式入口共用协调器和页面 · 隔离 MOCK'),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CloneFlowPreviewPage(scenario: scenario),
                ),
              ),
            ),
          for (final scenario in CloneCreationScenario.values)
            ListTile(
              title: Text(switch (scenario) {
                CloneCreationScenario.reusable => '选择模型并复用认证录音',
                CloneCreationScenario.absent => '无认证录音，进入完整认证',
                CloneCreationScenario.expired => '录音身份失效，回退认证',
                CloneCreationScenario.existing => '已有克隆，确认重新认证',
                CloneCreationScenario.processing => '继续已有处理中候选',
                CloneCreationScenario.failed => '已有失败候选与重新录制',
                CloneCreationScenario.insufficient => '克隆积分不足',
                CloneCreationScenario.loadFailure => '模型读取失败后重试',
              }),
              subtitle: const Text('共享底部弹层与候选页 · MOCK'),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CloneCreationPreviewPage(scenario: scenario),
                ),
              ),
            ),
          for (final item in const {
            '分模型克隆管理与删除': CloneManagementPreviewPage(),
            '删除失败与状态同步': CloneManagementPreviewPage(failFirstDelete: true),
            '删除成功但刷新失败': CloneManagementPreviewPage(failReadAfterDelete: true),
          }.entries)
            ListTile(
              title: Text(item.key),
              subtitle: const Text('复用正式模型页与音色页 · MOCK'),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => item.value),
              ),
            ),
          for (final scenario in ClonePreviewScenario.values)
            ListTile(
              title: Text(switch (scenario) {
                ClonePreviewScenario.success => '完整认证与克隆流程',
                ClonePreviewScenario.replacement => '替换身份确认',
                ClonePreviewScenario.denied => '采集取消或权限拒绝',
                ClonePreviewScenario.verificationFailure => '服务端认证失败',
                ClonePreviewScenario.generationFailure => '克隆生成失败',
                ClonePreviewScenario.previewFailure => '试听失败后重试',
                ClonePreviewScenario.confirmationFailure => '确认失败后重试',
              }),
              subtitle: const Text('合成端口；异常场景仅首次失败，无真实服务调用'),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CloneEnrollmentPreviewPage(
                    port: PreviewCloneEnrollmentPort(scenario),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
