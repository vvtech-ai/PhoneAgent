import '../domain/recording_audio.dart';
import 'device_recording_exporter.dart';
import 'recording_source_resolver.dart';

RecordingAudioRepository createRecordingRepository({
  required RecordingSourceResolver resolver,
  required DeviceRecordingExporter exporter,
  required String scope,
  required bool Function() isCurrent,
  DomesticRecordingOpen? openDomestic,
}) => throw UnsupportedError('Recording files require Android or iOS');
