import 'package:flutter/material.dart';
import '../../../../core/design/native_notice.dart';
import '../../domain/call_models.dart';
import '../controller/call_model_controller.dart';

/// Presentation feedback belongs to the initiating page and account only.
Future<bool> selectCallModelWithFeedback(
  BuildContext context,
  CallModelController controller,
  CallModel model, {
  required bool Function() isCurrent,
  required CallModelState Function() readState,
}) async {
  bool current() =>
      context.mounted &&
      controller.mounted &&
      isCurrent() &&
      ModalRoute.of(context)?.isCurrent == true;
  if (!current() || !model.available) return false;
  if (readState().saving || readState().voiceSaving) {
    showNativeNotice(context, '通话模型正在切换中');
    return false;
  }
  final unchanged =
      normalizeProvider(readState().catalog?.activeProvider ?? '') ==
      normalizeProvider(model.id);
  final saved = await controller.select(model);
  if (!context.mounted || !current()) return false;
  if (!unchanged) {
    final name = readState().catalog?.current?.name ?? model.name;
    showNativeNotice(
      context,
      saved ? '通话模型已切换为 $name' : '通话模型切换失败，请检查网络或本地服务连接',
    );
  }
  return saved;
}
