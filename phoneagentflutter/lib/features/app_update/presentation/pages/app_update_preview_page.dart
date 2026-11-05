import 'package:flutter/material.dart';
import '../../domain/app_update.dart';
import '../controller/app_update_controller.dart';
import 'app_update_page.dart';
import 'update_install_preview.dart';

class AppUpdatePreviewPage extends StatefulWidget {
  const AppUpdatePreviewPage({super.key});
  @override
  State<AppUpdatePreviewPage> createState() => _AppUpdatePreviewPageState();
}

class _AppUpdatePreviewPageState extends State<AppUpdatePreviewPage> {
  final _port = _PreviewUpdatePort();
  late final _controller = AppUpdateController(_port, _port);
  late final void Function() _remove;
  AppUpdateState _state = const AppUpdateState();
  @override
  void initState() {
    super.initState();
    _remove = _controller.addListener((value) {
      _state = value;
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppUpdatePage(
    state: _state,
    onCheck: _controller.check,
    previewControls: DropdownButton<String>(
      isExpanded: true,
      value: _port.scenario,
      items: const ['有新版本', '无新版本', '检查失败', '重要版本']
          .map((text) => DropdownMenuItem(value: text, child: Text(text)))
          .toList(),
      onChanged: _state.busy
          ? null
          : (value) => setState(() => _port.scenario = value!),
    ),
    onInstallPreview: () => Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const UpdateInstallPreview()),
    ),
  );
}

/// Never injected into the production provider or supplied real account data.
class _PreviewUpdatePort implements InstalledAppSource, AppUpdateRepository {
  String scenario = '有新版本';
  @override
  Future<InstalledApp> read() async =>
      const InstalledApp('com.example.preview', '1.0.0', 1);
  @override
  Future<AppUpdateRelease> check(InstalledApp app) async {
    if (scenario == '检查失败') throw StateError('Synthetic');
    return AppUpdateRelease(
      hasUpdate: scenario != '无新版本',
      packageName: app.packageName,
      versionName: '1.1.0',
      versionCode: 2,
      forceUpdate: scenario == '重要版本',
      releaseNotes: '合成说明：演练版本检查、失败重试和返回。',
      fileSize: 1024,
    );
  }
}
