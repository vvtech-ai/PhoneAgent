import 'dart:io';
import '../domain/recording_audio.dart';
import 'device_recording_exporter.dart';
import 'io_recording_repository.dart';
import 'recording_file_downloader.dart';
import 'recording_source_resolver.dart';

RecordingAudioRepository createRecordingRepository({
  required RecordingSourceResolver resolver,
  required DeviceRecordingExporter exporter,
  required String scope,
  required bool Function() isCurrent,
  DomesticRecordingOpen? openDomestic,
}) => IoRecordingRepository(
  resolver,
  () async => RecordingFileDownloader(
    root: Directory(await exporter.cacheRoot()),
    scope: scope,
    isCurrent: isCurrent,
    openDomestic: openDomestic,
  ),
);
