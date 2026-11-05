import 'package:flutter/material.dart';
import '../../domain/tools/conversation_permission.dart';

/// Presents only live action feedback; restored tool cards never populate notice.
class LocationPermissionNotice extends StatefulWidget {
  const LocationPermissionNotice({
    super.key,
    required this.notice,
    required this.onNotice,
    required this.active,
  });
  final String notice;
  final ValueChanged<String> onNotice;
  final bool active;

  @override
  State<LocationPermissionNotice> createState() =>
      _LocationPermissionNoticeState();
}

class _LocationPermissionNoticeState extends State<LocationPermissionNotice> {
  @override
  void initState() {
    super.initState();
    _present();
  }

  @override
  void didUpdateWidget(LocationPermissionNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice != widget.notice) _present();
  }

  void _present() {
    final notice = widget.notice;
    if (!widget.active || !isLocationPermissionToast(notice)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.active &&
          widget.notice == notice &&
          ModalRoute.of(context)?.isCurrent != false) {
        widget.onNotice(notice);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
