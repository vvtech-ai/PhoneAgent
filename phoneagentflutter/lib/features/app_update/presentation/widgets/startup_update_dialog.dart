import 'package:flutter/material.dart';
import '../../domain/startup_update.dart';
import 'native_update_dialog.dart';

class StartupUpdateDialog extends StatelessWidget {
  const StartupUpdateDialog({
    super.key,
    required this.offer,
    required this.onLater,
    required this.onInstall,
    this.previewControls,
  });
  final StartupUpdateOffer offer;
  final VoidCallback onLater, onInstall;
  final Widget? previewControls;
  @override
  Widget build(BuildContext context) {
    final release = offer.release;
    return PopScope(
      canPop: !release.forceUpdate,
      child: NativeUpdateDialog(
        title: release.forceUpdate ? '发现重要版本更新' : '发现新版本',
        version: release.versionName,
        notes: release.releaseNotes,
        force: release.forceUpdate,
        primary: '立即更新',
        onPrimary: onInstall,
        primaryKey: const Key('startup-update-install'),
        onLater: onLater,
        laterKey: const Key('startup-update-later'),
        extra: previewControls == null
            ? null
            : Column(
                children: [
                  const Text('MOCK · 启动更新演练，无真实下载或安装'),
                  previewControls!,
                ],
              ),
      ),
    );
  }
}
