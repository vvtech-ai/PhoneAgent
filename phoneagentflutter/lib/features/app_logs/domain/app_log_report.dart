import 'dart:typed_data';
import '../../../../core/diagnostics/device_environment.dart';

class AppLogBundle {
  const AppLogBundle({
    required this.watermark,
    required this.count,
    required this.bytes,
    required this.fileName,
    this.hasMore = false,
    this.environment,
  });
  final int watermark, count;
  final Uint8List bytes;
  final String fileName;
  final bool hasMore;
  final DeviceEnvironment? environment;
}

abstract interface class AppLogRepository {
  Future<AppLogBundle> prepare();
  Future<void> upload(AppLogBundle bundle);
  Future<void> acknowledge(AppLogBundle bundle);
}
