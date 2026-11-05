import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_logs/domain/app_log_report.dart';
import '../../app_logs/domain/format_device_environment.dart';
import '../domain/feedback.dart';
import 'feedback_state.dart';

class FeedbackController extends StateNotifier<FeedbackState> {
  FeedbackController({
    required this.gateway,
    required this.logs,
    required this.current,
    required this.deviceInfo,
  }) : super(const FeedbackState());
  final FeedbackGateway gateway;
  final AppLogRepository logs;
  final bool Function() current;
  final Future<String> Function() deviceInfo;
  FeedbackRequest? _request;
  AppLogBundle? _bundle;
  bool _cleanupPending = false;
  FeedbackState get snapshot => state;
  bool get _active => mounted && current();

  void edit({String? description, String? contact, bool? includeLogs}) {
    if (!_active || state.busy || state.success) return;
    _invalidate();
    state = state.copy(
      description: description,
      contact: contact,
      includeLogs: includeLogs,
      error: '',
    );
  }

  void removeImage(int index) {
    if (!_active || state.busy || state.success) return;
    final images = [...state.images]..removeAt(index);
    _invalidate();
    state = state.copy(images: images, error: '');
  }

  void _invalidate() {
    _request = null;
    _bundle = null;
  }

  Future<void> addImages(
    Future<List<FeedbackImage>> Function(int remaining) pick,
  ) async {
    if (!_active || state.busy || state.success || state.images.length >= 6) {
      return;
    }
    state = state.copy(busy: true, processing: true, error: '');
    try {
      final images = await pick(6 - state.images.length);
      if (!_active) return;
      if (images.length + state.images.length > 6 ||
          images.any(
            (i) => i.bytes.isEmpty || i.bytes.length > 2 * 1024 * 1024,
          )) {
        throw const FormatException('图片处理失败，请重新选择');
      }
      if (images.isNotEmpty) {
        _invalidate();
        state = state.copy(
          images: List.unmodifiable([...state.images, ...images]),
        );
      }
    } on FormatException catch (error) {
      if (_active) state = state.copy(error: error.message);
    } catch (_) {
      if (_active) state = state.copy(error: '图片处理失败，请重新选择');
    } finally {
      if (_active) state = state.copy(busy: false, processing: false);
    }
  }

  Future<void> submit() async {
    if (!_active || state.busy) return;
    if (state.success) {
      await _cleanup();
      return;
    }
    final invalid = validateFeedback(state.description, state.contact);
    if (invalid != null) {
      state = state.copy(error: invalid);
      return;
    }
    state = state.copy(busy: true, error: '');
    try {
      if (_request == null) {
        if (state.includeLogs) {
          _bundle ??= await logs.prepare();
        }
        final info = await _readDeviceInfo();
        if (!_active) return;
        _request = FeedbackRequest(
          description: state.description,
          contact: state.contact,
          images: state.images,
          logs: _bundle,
          deviceInfo: info,
        );
      }
      if (!_active) return;
      await gateway.submit(_request!);
      // Acknowledge only the captured account journal and accepted watermark.
      _cleanupPending = _bundle != null;
      await _cleanup();
      if (_active) state = state.copy(success: true, busy: false);
    } catch (_) {
      if (_active) {
        state = state.copy(busy: false, error: '提交失败，请重试。已保留你填写的内容。');
      }
    }
  }

  Future<String> _readDeviceInfo() async {
    if (_bundle?.environment case final environment?) {
      return formatDeviceEnvironment(environment);
    }
    try {
      return await deviceInfo();
    } catch (_) {
      if (state.includeLogs) rethrow;
      return '';
    }
  }

  Future<void> _cleanup() async {
    if (!_cleanupPending || _bundle == null) return;
    try {
      await logs.acknowledge(_bundle!);
      _cleanupPending = false;
    } catch (_) {
      /* Accepted feedback must never be uploaded again for cleanup. */
    }
  }
}
