import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../conversation/domain/agent_protocol.dart';
import '../../domain/ocr_attachment.dart';
import '../../domain/ocr_image_source.dart';
import '../../domain/ocr_persistence.dart';
import 'ocr_controller.dart';

class OcrSessionState {
  const OcrSessionState({
    this.processing = const OcrState([]),
    this.images = const {},
    this.picking = false,
    this.notice = '',
  });
  final OcrState processing;
  final Map<String, Uint8List> images;
  final bool picking;
  final String notice;
  bool get busy => picking || processing.busy;
}

/// Account/page-scoped orchestration; platform IO stays behind injected ports.
class OcrSessionController extends StateNotifier<OcrSessionState> {
  OcrSessionController({
    required this.sessionId,
    required this.source,
    required OcrRecognizer recognizer,
    required this.repository,
    required this.nextId,
    required this.isCurrent,
    required this.initialOpening,
    this.initialSkillId,
    this.selectedContact,
  }) : super(const OcrSessionState()) {
    _ocr = OcrController(recognizer, _SessionCommitter(_commit), nextId);
    _removeListener = _ocr.addListener(
      (_) => _publish(),
      fireImmediately: false,
    );
  }
  final String sessionId;
  final OcrImageSource source;
  final OcrAttachmentRepository repository;
  final String Function() nextId;
  final bool Function() isCurrent;
  final String? Function() initialOpening;
  final String? Function()? initialSkillId;
  final SelectedContactContext? Function()? selectedContact;
  late final OcrController _ocr;
  late final void Function() _removeListener;
  final _selected = <String, SelectedOcrImage>{};
  final _images = <String, Uint8List>{};
  final _persisted = <String, PersistedOcrAttachment>{};
  final _loading = <String>{}, _attempted = <String>{};
  Future<void> _imageQueue = Future<void>.value();
  bool _closed = false, _picking = false;
  String _notice = '';
  OcrSessionState get snapshot => state;
  bool get _alive => mounted && !_closed && isCurrent();

  Map<String, Object?>? get userContext {
    if (!_alive) return null;
    final successful = _ocr.snapshot.successful;
    if (successful.isEmpty) return null;
    return {
      'ocrAttachments': [
        for (final item in successful)
          if (_persisted[item.id] case final attachment?) attachment.context,
      ],
    };
  }

  Future<void> pick(int sourceAnchor, {int Function()? currentAnchor}) async {
    if (!_alive || state.busy) return;
    _picking = true;
    _notice = '';
    _publish();
    String? id;
    try {
      final image = await source.pick();
      if (!_alive || image == null) return;
      final selectedAnchor = currentAnchor?.call() ?? sourceAnchor;
      final bytes = await image.read();
      if (!_alive) return;
      if (bytes.isEmpty ||
          bytes.length != image.size ||
          bytes.length > ocrMaxImageBytes) {
        throw const OcrImageException(OcrImageFailure.interrupted);
      }
      id = 'ocr-${nextId()}';
      _selected[id] = image;
      _images[id] = bytes;
      _picking = false;
      await _ocr.select(image.path, selectedAnchor, id: id);
    } catch (error) {
      if (_alive) _notice = _selectionNotice(error);
    } finally {
      _selected.remove(id);
      _picking = false;
      _publish();
    }
  }

  Future<OcrContent> _commit(
    OcrAttachment item,
    OcrRecognition recognition,
  ) async {
    if (!_alive) throw StateError('OCR session closed');
    final image = _selected[item.id], bytes = _images[item.id];
    if (image == null || bytes == null) {
      throw StateError('OCR selection expired');
    }
    final receipt = await repository.upload(
      OcrUpload(
        sessionId: sessionId,
        attachment: item,
        bytes: bytes,
        fileName: image.name,
        mimeType: image.mimeType,
        recognition: recognition,
        initialOpening: initialOpening(),
        initialSkillId: initialSkillId?.call(),
        selectedContact: selectedContact?.call(),
      ),
    );
    if (!_alive) throw StateError('OCR session closed');
    if (receipt.attachment.sessionId != sessionId ||
        receipt.attachment.id != item.id) {
      throw StateError('OCR identity mismatch');
    }
    _persisted[item.id] = receipt.attachment;
    return receipt.attachment.content;
  }

  void synchronize(Iterable<PersistedOcrAttachment> history) {
    if (!_alive) return;
    final current = history
        .where((item) => item.sessionId == sessionId)
        .toList();
    for (final item in current) {
      _persisted[item.id] = item;
      _ocr.reserveOrdinal(item.ordinal + 1);
    }
    _ocr.synchronize(
      current
          .where((item) => _images.containsKey(item.id))
          .map((item) => item.display(item.id)),
    );
    for (final item in current) {
      if (!_images.containsKey(item.id) && !_attempted.contains(item.id)) {
        _attempted.add(item.id);
        _imageQueue = _imageQueue.then((_) => retryImage(item.id));
      }
    }
  }

  Future<void> retryImage(String id) async {
    final attachment = _persisted[id];
    if (!_alive ||
        attachment == null ||
        _loading.contains(id) ||
        _images.containsKey(id)) {
      return;
    }
    _loading.add(id);
    _attempted.add(id);
    try {
      final bytes = await repository.loadImage(attachment);
      if (!_alive) return;
      if (bytes.length != attachment.fileSize ||
          bytes.length > ocrMaxImageBytes) {
        throw const FormatException('OCR image size mismatch');
      }
      _images[id] = bytes;
      _ocr.synchronize([(_persisted[id] ?? attachment).display(id)]);
    } catch (_) {
      // v65 skips an unavailable history image, including its usable context.
    } finally {
      _loading.remove(id);
      _publish();
    }
  }

  void _publish() {
    if (!_alive) return;
    state = OcrSessionState(
      processing: _ocr.snapshot,
      images: Map.unmodifiable(_images),
      picking: _picking,
      notice: _notice,
    );
  }

  static String _selectionNotice(Object error) => switch (error) {
    OcrImageException(reason: OcrImageFailure.unavailable) =>
      '当前平台不支持本地图片识别，可使用独立演练查看交互',
    OcrImageException(reason: OcrImageFailure.tooLarge) => '图片不能超过10MiB，请重新选择',
    OcrImageException(reason: OcrImageFailure.unsupported) =>
      '请选择JPEG、PNG、WebP或HEIC图片',
    OcrImageException(reason: OcrImageFailure.interrupted) => '上次图片选择已中断，请重新选择',
    _ => '无法读取所选图片，请重新选择',
  };

  void close() {
    if (_closed) return;
    _closed = true;
    _removeListener();
    _ocr.dispose();
    _selected.clear();
    _images.clear();
    _persisted.clear();
    _loading.clear();
    _attempted.clear();
    if (mounted) state = const OcrSessionState();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

class _SessionCommitter implements OcrCommitter {
  const _SessionCommitter(this.callback);
  final Future<OcrContent> Function(OcrAttachment, OcrRecognition) callback;
  @override
  Future<OcrContent> commit(OcrAttachment item, OcrRecognition recognition) =>
      callback(item, recognition);
}
