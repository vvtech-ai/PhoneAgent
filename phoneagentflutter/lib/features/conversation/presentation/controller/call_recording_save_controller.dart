import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/call_recording_save.dart';

class CallRecordingSaveState {
  const CallRecordingSaveState({this.saving = false, this.message = ''});
  final bool saving;
  final String message;
}

class CallRecordingSaveController
    extends StateNotifier<CallRecordingSaveState> {
  CallRecordingSaveController(this.useCase, {required this.isCurrent})
    : super(const CallRecordingSaveState());
  final SaveCallRecording useCase;
  final bool Function() isCurrent;
  bool _closed = false;

  Future<void> save() async {
    if (_closed || !isCurrent() || state.saving) return;
    state = const CallRecordingSaveState(saving: true);
    try {
      final result = await useCase.save();
      if (_closed || !isCurrent()) return;
      state = CallRecordingSaveState(
        message: switch (result) {
          CallRecordingSaveResult.cancelled => '',
          CallRecordingSaveResult.saved => '录音已保存',
          CallRecordingSaveResult.savedCleanupPending => '录音已保存',
        },
      );
    } catch (_) {
      if (!_closed && isCurrent()) {
        state = const CallRecordingSaveState(message: '录音保存失败，请重试');
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(useCase.close().catchError((Object _) {}));
    super.dispose();
  }
}
