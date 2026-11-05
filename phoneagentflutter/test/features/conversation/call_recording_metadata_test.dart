import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_recording.dart';
import 'package:phone_agent/features/conversation/presentation/controller/call_recording_metadata_observer.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  test('RESERVED keeps observing the same recording until READY', () {
    fakeAsync((time) {
      final repo = _Repository()..status = 'RESERVED';
      final seen = <CallRecordingInfo>[];
      final observer = CallRecordingMetadataObserver(
        repository: repo,
        onMetadata: seen.add,
        isCurrent: () => true,
      );
      observer.start();
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 2));
      expect(repo.reads, 2);
      repo.status = 'READY';
      time.elapse(const Duration(seconds: 2));
      expect(seen.map((info) => info.status), [
        'RESERVED',
        'RESERVED',
        'READY',
      ]);
      expect(time.pendingTimers, isEmpty);
      observer.close();
    });
  });
  test(
    'processing observes every two seconds, READY stops, never loads media',
    () {
      fakeAsync((time) {
        final repo = _Repository();
        final seen = <CallRecordingInfo>[];
        final observer = CallRecordingMetadataObserver(
          repository: repo,
          onMetadata: seen.add,
          isCurrent: () => true,
        );
        observer.start();
        observer.start();
        time.flushMicrotasks();
        expect(repo.reads, 1);
        time.elapse(const Duration(seconds: 2));
        expect(repo.reads, 2);
        repo.status = 'READY';
        time.elapse(const Duration(seconds: 2));
        expect(seen.last.status, 'READY');
        time.elapse(const Duration(seconds: 80));
        expect(repo.reads, 3);
        expect(time.pendingTimers, isEmpty);
        observer.close();
      });
    },
  );
  test(
    'permanent processing has hard 60 second deadline, foreground can refresh',
    () {
      fakeAsync((time) {
        final repo = _Repository();
        final observer = CallRecordingMetadataObserver(
          repository: repo,
          onMetadata: (_) {},
          isCurrent: () => true,
        );
        observer.start();
        time.elapse(const Duration(seconds: 120));
        expect(repo.reads, 30);
        expect(time.pendingTimers, isEmpty);
        observer.start();
        time.flushMicrotasks();
        expect(repo.reads, 31);
        observer.close();
      });
    },
  );
  test('failure preserves last info and retries only within 60 seconds', () {
    fakeAsync((time) {
      final repo = _Repository();
      final seen = <CallRecordingInfo>[];
      final observer = CallRecordingMetadataObserver(
        repository: repo,
        onMetadata: seen.add,
        isCurrent: () => true,
      );
      observer.start();
      time.flushMicrotasks();
      repo.fail = true;
      time.elapse(const Duration(seconds: 80));
      expect(repo.reads, greaterThan(2));
      expect(seen, hasLength(1));
      expect(time.pendingTimers, isEmpty);
      observer.close();
    });
  });
  test('one metadata failure retries within the same observation budget', () {
    fakeAsync((time) {
      final repo = _Repository()..fail = true;
      final seen = <CallRecordingInfo>[];
      final observer = CallRecordingMetadataObserver(
        repository: repo,
        onMetadata: seen.add,
        isCurrent: () => true,
      );
      observer.start();
      time.flushMicrotasks();
      expect(repo.reads, 1);
      repo.fail = false;
      repo.status = 'READY';
      time.elapse(const Duration(seconds: 2));
      expect(repo.reads, 2);
      expect(seen.single.status, 'READY');
      expect(time.pendingTimers, isEmpty);
      observer.close();
    });
  });
  test('stop and replacement observation reject older in-flight response', () {
    fakeAsync((time) {
      final repo = _Repository()..pending = Completer<CallRecordingInfo>();
      final seen = <CallRecordingInfo>[];
      final observer = CallRecordingMetadataObserver(
        repository: repo,
        onMetadata: seen.add,
        isCurrent: () => true,
      );
      observer.start();
      observer.stop();
      final old = repo.pending!;
      repo.pending = null;
      repo.status = 'READY';
      observer.start();
      time.flushMicrotasks();
      old.complete(
        const CallRecordingInfo(callId: 'call', status: 'RECORDING'),
      );
      time.flushMicrotasks();
      expect(seen.map((e) => e.status), ['READY']);
      observer.close();
    });
  });
  test('hung metadata cannot extend observation beyond deadline', () {
    fakeAsync((time) {
      final repo = _Repository()..pending = Completer<CallRecordingInfo>();
      final seen = <CallRecordingInfo>[];
      final observer = CallRecordingMetadataObserver(
        repository: repo,
        onMetadata: seen.add,
        isCurrent: () => true,
      );
      observer.start();
      time.elapse(const Duration(seconds: 60));
      repo.pending!.complete(
        const CallRecordingInfo(callId: 'call', status: 'READY'),
      );
      time.flushMicrotasks();
      expect(seen, isEmpty);
      expect(time.pendingTimers, isEmpty);
      observer.close();
    });
  });
  test('account replacement and close cannot update or restart', () {
    fakeAsync((time) {
      final repo = _Repository()..pending = Completer<CallRecordingInfo>();
      final seen = <CallRecordingInfo>[];
      var current = true;
      final observer = CallRecordingMetadataObserver(
        repository: repo,
        onMetadata: seen.add,
        isCurrent: () => current,
      );
      observer.start();
      current = false;
      repo.pending!.complete(
        const CallRecordingInfo(callId: 'call', status: 'READY'),
      );
      time.flushMicrotasks();
      observer.close();
      current = true;
      observer.start();
      time.elapse(const Duration(minutes: 2));
      expect(seen, isEmpty);
      expect(repo.reads, 1);
      expect(time.pendingTimers, isEmpty);
    });
  });
}

class _Repository implements CallRecordingRepository {
  String status = 'PROCESSING';
  int reads = 0;
  bool fail = false;
  Completer<CallRecordingInfo>? pending;
  @override
  Future<CallRecordingInfo> metadata() async {
    ++reads;
    if (fail) throw StateError('synthetic failure');
    if (pending != null) return pending!.future;
    return CallRecordingInfo(
      callId: 'call',
      status: status,
      durationMillis: 12000,
    );
  }

  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async => throw StateError('Must not load media');
  @override
  void close() {}
}
