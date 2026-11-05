import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../../core/diagnostics/clone_diagnostics.dart';
import '../../../core/diagnostics/diagnostic_event.dart';

class ClonePreviewDiagnostics {
  const ClonePreviewDiagnostics(this.log);
  final CloneDiagnostics? log;
  void emit(
    DiagnosticClonePreviewDetails details,
    DiagnosticResult result, {
    int elapsedMs = 0,
  }) => emitDiagnostic(
    log?.sink,
    DiagnosticEvent(
      operation: DiagnosticOperation.voiceCloneFlow,
      result: result,
      sessionId: log?.sessionId ?? '',
      elapsedMs: elapsedMs,
      cloneFlow: DiagnosticCloneFlowDetails(
        stage: DiagnosticCloneStage.previewPlayback,
        platform: log?.platform ?? 'other',
      ),
      clonePreview: details,
    ),
  );

  Future<T> run<T>(ClonePreviewStage stage, Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    emit(DiagnosticClonePreviewDetails(stage: stage), DiagnosticResult.started);
    try {
      final result = await action();
      emit(
        DiagnosticClonePreviewDetails(stage: stage),
        DiagnosticResult.succeeded,
        elapsedMs: watch.elapsedMilliseconds,
      );
      return result;
    } catch (error) {
      failed(stage, error, elapsedMs: watch.elapsedMilliseconds);
      rethrow;
    }
  }

  void failed(ClonePreviewStage stage, Object error, {int elapsedMs = 0}) {
    var code = 'other', domain = '';
    int? nativeCode;
    Map<Object?, Object?> metadata = const {};
    if (error is PlatformException) {
      code =
          const {
            'DarwinAudioError',
            'AudioPlayerError',
            'UnexpectedError',
          }.contains(error.code)
          ? error.code
          : 'other';
      // Extract only a fixed NSError domain and its numeric code. Never emit text.
      final match =
          RegExp(
            r'(AVFoundationErrorDomain|NSOSStatusErrorDomain|NSCocoaErrorDomain)\s+Code=(-?\d{1,10})(?!\d)',
          ).firstMatch(
            '${error.message ?? ''} ${error.details is String ? error.details : ''}',
          );
      domain = match?.group(1) ?? '';
      nativeCode = int.tryParse(match?.group(2) ?? '');
      if (error.details is Map) {
        metadata = error.details as Map;
        domain = metadata['errorDomain'] is String
            ? metadata['errorDomain'] as String
            : '';
        nativeCode = metadata['nativeCode'] is int
            ? metadata['nativeCode'] as int
            : null;
      }
    } else if (error is MissingPluginException) {
      code = 'missingPlugin';
    } else if (error is TimeoutException) {
      code = 'timeout';
    } else if (error is StateError) {
      code = 'state';
    } else if (error is FormatException) {
      code = 'format';
    } else if (error.runtimeType.toString() == 'FileSystemException') {
      code = 'fileSystem';
    }
    emit(
      DiagnosticClonePreviewDetails(
        stage: stage,
        errorCode: code,
        errorDomain: domain,
        nativeCode: nativeCode,
        nativeStep: metadata['nativeStep'] is String
            ? metadata['nativeStep'] as String
            : '',
        sessionCategory: metadata['sessionCategory'] is String
            ? metadata['sessionCategory'] as String
            : '',
        sessionMode: metadata['sessionMode'] is String
            ? metadata['sessionMode'] as String
            : '',
        sessionOptions: metadata['sessionOptions'] is int
            ? metadata['sessionOptions'] as int
            : null,
        nativeAttempt: metadata['nativeAttempt'] is int
            ? metadata['nativeAttempt'] as int
            : null,
      ),
      DiagnosticResult.failed,
      elapsedMs: elapsedMs,
    );
  }

  void input(Uint8List bytes) {
    if (log == null) return;
    // Inspection is bounded; it observes headers and never changes decoding.
    bool tag(int offset, String value) =>
        offset + value.length <= bytes.length &&
        List.generate(value.length, (i) => bytes[offset + i]).join(',') ==
            value.codeUnits.join(',');
    var container = 'unknown';
    int? format, channels, rate, bits, data;
    if (tag(0, 'RIFF') && tag(8, 'WAVE')) {
      container = 'wav';
      final view = ByteData.sublistView(bytes);
      var offset = 12;
      for (var count = 0; count < 128 && offset + 8 <= bytes.length; count++) {
        final size = view.getUint32(offset + 4, Endian.little);
        final start = offset + 8;
        if (size > bytes.length - start) break;
        if (tag(offset, 'fmt ') && size >= 16) {
          format = view.getUint16(start, Endian.little);
          channels = view.getUint16(start + 2, Endian.little);
          rate = view.getUint32(start + 4, Endian.little);
          bits = view.getUint16(start + 14, Endian.little);
        }
        if (tag(offset, 'data')) data = size;
        offset = start + size + (size & 1);
      }
    } else if (bytes.length >= 2 &&
        bytes[0] == 255 &&
        bytes[1] & 0xf6 == 0xf0) {
      container = 'aac';
    } else if (tag(0, 'ID3') ||
        (bytes.length >= 2 && bytes[0] == 255 && bytes[1] & 0xe0 == 0xe0)) {
      container = 'mp3';
    } else if (tag(0, 'OggS')) {
      container = 'ogg';
    } else if (tag(0, 'fLaC')) {
      container = 'flac';
    } else if (tag(4, 'ftyp')) {
      container = 'mp4';
    }
    emit(
      DiagnosticClonePreviewDetails(
        stage: ClonePreviewStage.input,
        container: container,
        byteCount: bytes.length,
        wavFormat: format,
        channels: channels,
        sampleRate: rate,
        bitsPerSample: bits,
        dataBytes: data,
      ),
      DiagnosticResult.received,
    );
  }
}
