import '../translation_directory.dart';
import 'dart:math';
import 'dart:typed_data';
import '../translation_call_view.dart';
import 'sip_lease.dart';

final _modelRandom = Random.secure();
String newDomesticModelToken() => List.generate(
  16,
  (_) => _modelRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class DomesticModelConfiguration {
  DomesticModelConfiguration({
    required this.provider,
    required this.uri,
    required Map<String, String> headers,
    required this.model,
    this.voice = 'Nofish',
    this.outputSampleRate = 16000,
    this.asrModel = '',
    this.directory,
    this.sourceLanguages = const [],
    this.targetLanguages = const [],
    this.sourceCodes = const {},
    this.targetCodes = const {},
  }) : headers = Map.unmodifiable(headers) {
    if (!const {'QWEN', 'DOUBAO'}.contains(provider) ||
        uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        model.isEmpty ||
        headers.isEmpty ||
        headers.entries.any(
          (entry) =>
              entry.value.trim().isEmpty ||
              entry.key.contains(RegExp(r'[^A-Za-z0-9-]')) ||
              entry.value.contains(RegExp(r'[\r\n\x00]')),
        ) ||
        !const {16000, 24000, 48000}.contains(outputSampleRate)) {
      throw const SipLeaseFailure('MODEL_CONFIGURATION_UNAVAILABLE');
    }
  }
  final TranslationDirectory? directory;
  final String provider, model, voice, asrModel;
  final Map<String, String> sourceCodes, targetCodes;
  final List<String> sourceLanguages, targetLanguages;
  final Uri uri;
  final Map<String, String> headers;
  final int outputSampleRate;
  @override
  String toString() => 'DomesticModelConfiguration($provider,<private>)';
}

abstract interface class DomesticModelConfigurationSource {
  Future<DomesticModelConfiguration?> load(String provider);
}

abstract interface class ContextualDomesticModelConfigurationSource
    implements DomesticModelConfigurationSource {
  Future<DomesticModelConfiguration?> loadFor(
    String countryIso,
    String provider,
  );
}

abstract interface class SelectedDomesticModelConfigurationSource
    implements ContextualDomesticModelConfigurationSource {
  Future<DomesticModelConfiguration?> loadSelectedFor(
    String countryIso,
    String modelId,
  );
}

sealed class DomesticModelEvent {
  const DomesticModelEvent();
}

class DomesticModelReady extends DomesticModelEvent {
  const DomesticModelReady();
}

class DomesticModelTranscript extends DomesticModelEvent {
  const DomesticModelTranscript(this.transcript);
  final TranslationTranscript transcript;
}

class DomesticModelAudio extends DomesticModelEvent {
  const DomesticModelAudio(this.pcm16k);
  final Uint8List pcm16k;
}

class DomesticModelAudioDone extends DomesticModelEvent {
  const DomesticModelAudioDone();
}

class DomesticModelResponseDone extends DomesticModelAudioDone {
  const DomesticModelResponseDone();
}

class DomesticModelEnded extends DomesticModelEvent {
  const DomesticModelEnded();
}

class DomesticModelError extends DomesticModelEvent {
  const DomesticModelError(this.code);
  final String code;
}

abstract interface class DomesticModelProtocol {
  Uri get uri;
  Map<String, String> get headers;
  Object start();
  Object audio(Uint8List pcm16k);
  Object finish();
  List<DomesticModelEvent> decode(Object message);
}
