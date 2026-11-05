import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_recording_save.dart';
import 'package:phone_agent/features/conversation/presentation/controller/call_recording_save_controller.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  late _Ports ports;
  late SaveCallRecording useCase;
  late CallRecordingSaveController controller;
  var current = true;
  setUp(() {
    ports = _Ports();
    current = true;
    useCase = SaveCallRecording(
      repository: ports,
      download: ports,
      destination: _Destination(ports),
      fileName: callRecordingFileName('call-1'),
      isCurrent: () => current,
    );
    controller = CallRecordingSaveController(useCase, isCurrent: () => current);
  });
  tearDown(() => controller.dispose());
  test(
    'reserve before fresh token; download, write and local cleanup, never playback',
    () async {
      await controller.save();
      expect(ports.calls, [
        'reserve',
        'source:true',
        'download',
        'write',
        'remove',
      ]);
      expect(controller.state.message, '录音已保存');
      expect(controller.state.saving, false);
      await controller.save();
      expect(ports.calls.where((e) => e == 'source:true'), hasLength(2));
    },
  );
  test('cancel selection never requests source', () async {
    ports.selected = false;
    await controller.save();
    expect(ports.calls, ['reserve', 'abort']);
    expect(controller.state.message, '');
  });
  test(
    'iOS export cancellation cleans private download without success',
    () async {
      ports.written = false;
      await controller.save();
      expect(ports.calls, [
        'reserve',
        'source:true',
        'download',
        'write',
        'abort',
        'remove',
      ]);
      expect(controller.state.message, '');
    },
  );
  test(
    'each failing stage cleans only this operation and exposes no raw error',
    () async {
      for (final stage in ['reserve', 'source:true', 'download', 'write']) {
        ports.calls.clear();
        ports.fail = stage;
        await controller.save();
        expect(ports.calls, contains('abort'));
        expect(ports.calls.contains('remove'), stage == 'write');
        expect(controller.state.message, '录音保存失败，请重试');
        expect(controller.state.saving, false);
      }
    },
  );
  test(
    'completed export with cleanup error does not invite duplicate save',
    () async {
      ports.fail = 'remove';
      await controller.save();
      expect(controller.state.message, '录音已保存');
      expect(ports.calls, isNot(contains('abort')));
    },
  );
  test('duplicate save while picker pending is single flight', () async {
    ports.selection = Completer<bool>();
    final first = controller.save();
    await controller.save();
    expect(ports.calls, ['reserve']);
    ports.selection!.complete(false);
    await first;
    expect(controller.state.saving, false);
  });
  test('account changes while selecting cannot request a token', () async {
    ports.selection = Completer<bool>();
    final future = controller.save();
    current = false;
    ports.selection!.complete(true);
    await future;
    expect(ports.calls, ['reserve', 'abort']);
  });
  test('closed use case rejects late downloaded file and cleans it', () async {
    ports.downloading = Completer<RecordingAudioAsset>();
    final future = controller.save();
    await Future<void>.delayed(Duration.zero);
    await useCase.close();
    ports.downloading!.complete(_Ports.local);
    await future;
    expect(ports.calls, isNot(contains('write')));
    expect(
      ports.calls,
      containsAll(['download-close', 'destination-close', 'remove']),
    );
  });
  test(
    'filename follows fixed v65 suffix and excludes directory components',
    () {
      expect(callRecordingFileName('../call-1'), 'call-recording-call-1.m4a');
      expect(callRecordingFileName('!'), 'call-recording-recording.m4a');
      expect(callRecordingFileName('a' * 90), 'call-recording-${'a' * 48}.m4a');
    },
  );
}

class _Ports implements RecordingAudioRepository, CallRecordingDownload {
  static final local = RecordingAudioAsset(
    '/synthetic/file.m4a',
    'local.m4a',
    'audio/wav',
    size: 10,
    sha256: 'a' * 64,
  );
  final calls = <String>[];
  String? fail;
  bool selected = true, written = true;
  Completer<bool>? selection;
  Completer<RecordingAudioAsset>? downloading;
  void step(String name) {
    calls.add(name);
    if (fail == name) throw StateError('synthetic-private');
  }

  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async {
    step('source:$retry');
    return RecordingAudioAsset.remote(
      Uri.parse('https://example.test/token'),
      'x',
      'audio/wav',
    );
  }

  @override
  Future<RecordingAudioAsset> download(RecordingAudioAsset source) async {
    step('download');
    return downloading == null ? local : downloading!.future;
  }

  @override
  Future<void> remove(RecordingAudioAsset asset) async => step('remove');
  @override
  void close() => calls.add('download-close');
}

class _Destination implements CallRecordingDestination {
  _Destination(this.ports);
  final _Ports ports;
  @override
  Future<bool> reserve(String name) async {
    ports.step('reserve');
    expect(name, 'call-recording-call-1.m4a');
    return ports.selection == null ? ports.selected : ports.selection!.future;
  }

  @override
  Future<bool> write(RecordingAudioAsset asset) async {
    ports.step('write');
    expect(asset.fileName, 'call-recording-call-1.m4a');
    return ports.written;
  }

  @override
  Future<void> abort() async => ports.step('abort');
  @override
  Future<void> close() async => ports.step('destination-close');
}
