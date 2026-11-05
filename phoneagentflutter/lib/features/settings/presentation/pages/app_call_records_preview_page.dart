import 'package:flutter/material.dart';
import '../../../dialer/presentation/widgets/dial_recent_list.dart';
import '../controller/app_call_records_preview_controller.dart';
import '../widgets/developer_list_controls.dart';

class AppCallRecordsPreviewPage extends StatefulWidget {
  const AppCallRecordsPreviewPage({super.key});
  @override
  State<AppCallRecordsPreviewPage> createState() =>
      _AppCallRecordsPreviewPageState();
}

class _AppCallRecordsPreviewPageState extends State<AppCallRecordsPreviewPage> {
  final controller = AppCallRecordsPreviewController();
  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('本机记录与列表演练')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('MOCK · 全部为内存合成数据，不读取真实账号、系统通讯录或通话记录'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.busy || controller.listState.busy
                  ? null
                  : controller.addTranslation,
              child: const Text('追加合成翻译记录'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('模拟本机保存失败'),
              value: controller.store.failWrite,
              onChanged: controller.busy || controller.listState.busy
                  ? null
                  : controller.failWrite,
            ),
            if (controller.error.isNotEmpty) Text(controller.error),
            DeveloperListControls(
              state: controller.listState,
              onApply: controller.lists.apply,
            ),
            const Divider(),
            Text(
              '当前联系人：${controller.contactState.contacts.length} · 任务刷新：${controller.taskRefreshes}',
            ),
            const Text('联系人与任务为演练输入；下方为正式最近列表组件'),
            DialRecentList(
              state: controller.recentState,
              onSelect: controller.select,
              onRetry: controller.recent.load,
            ),
            if (controller.selection.isNotEmpty)
              Text('选中号码：${controller.selection}'),
          ],
        ),
      ),
    ),
  );
}
