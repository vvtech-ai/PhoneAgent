import 'dart:typed_data';
import '../../domain/sip/domestic_translation_model.dart';
import '../../domain/sip/sip_lease.dart';
import 'doubao_protobuf.dart';
import 'doubao_transcript_accumulator.dart';

class DoubaoTranslationProtocol implements DomesticModelProtocol {
  DoubaoTranslationProtocol({
    required this.configuration,
    required String leg,
    required this.sourceLanguage,
    required this.targetLanguage,
    String Function()? token,
    DateTime Function()? now,
  }) : _connectionId = (token ?? newDomesticModelToken)(),
       _sessionId = (token ?? newDomesticModelToken)(),
       _transcript = DoubaoTranscriptAccumulator(
         leg: leg,
         sourceLanguage: sourceLanguage,
         targetLanguage: targetLanguage,
         token: token,
         now: now,
       ) {
    if (configuration.provider != 'DOUBAO' ||
        configuration.outputSampleRate != 16000) {
      throw const SipLeaseFailure('INVALID_MODEL_PROVIDER');
    }
  }
  final DomesticModelConfiguration configuration;
  final String sourceLanguage, targetLanguage, _connectionId, _sessionId;
  final DoubaoTranscriptAccumulator _transcript;
  int _sequence = 0;
  @override
  Uri get uri => configuration.uri;
  @override
  Map<String, String> get headers => configuration.headers;
  Uint8List _request(int event, {bool initial = false, Uint8List? audio}) {
    final meta = DoubaoProtoWriter();
    if (initial) {
      meta.text(1, configuration.model);
      meta.text(4, configuration.model);
    }
    meta.text(5, _connectionId);
    meta.text(6, _sessionId);
    meta.integer(7, _sequence++);
    final request = DoubaoProtoWriter()
      ..bytes(1, meta.build())
      ..integer(2, event);
    if (initial || audio != null) {
      final source = DoubaoProtoWriter();
      if (initial) {
        source.text(4, 'wav');
        source.text(5, 'raw');
        source.text(
          6,
          configuration.sourceCodes[sourceLanguage] ??
              _language(sourceLanguage),
        );
      }
      source.integer(7, 16000);
      source.integer(8, 16);
      source.integer(9, 1);
      if (audio != null) source.bytes(14, audio);
      request.bytes(4, source.build());
    }
    if (initial) {
      final target = DoubaoProtoWriter()
        ..text(4, 'pcm')
        ..text(
          6,
          configuration.targetCodes[targetLanguage] ??
              _language(targetLanguage),
        )
        ..integer(7, 16000);
      request.bytes(5, target.build());
      final parameters = DoubaoProtoWriter()
        ..text(1, 's2s')
        ..text(
          2,
          configuration.sourceCodes[sourceLanguage] ??
              _language(sourceLanguage),
        )
        ..text(
          3,
          configuration.targetCodes[targetLanguage] ??
              _language(targetLanguage),
        );
      request.bytes(6, parameters.build());
    }
    return request.build();
  }

  @override
  Uint8List start() => _request(100, initial: true);
  @override
  Uint8List audio(Uint8List pcm16k) {
    if (pcm16k.isEmpty || pcm16k.length.isOdd || pcm16k.length > 64000) {
      throw const SipLeaseFailure('INVALID_PCM');
    }
    return _request(200, audio: pcm16k);
  }

  @override
  Uint8List finish() => _request(102);
  @override
  List<DomesticModelEvent> decode(Object message) {
    try {
      if (message is! List<int>) {
        throw const SipLeaseFailure('MODEL_PROTOCOL_ERROR');
      }
      final response = DoubaoProtoResponse.decode(Uint8List.fromList(message));
      if (response.status != 0 && response.status != 20000000) {
        return const [DomesticModelError('MODEL_SERVICE_ERROR')];
      }
      if (response.event == 150) return const [DomesticModelReady()];
      if (response.event == 153) {
        return const [DomesticModelError('MODEL_SESSION_FAILED')];
      }
      if (response.event == 352) {
        if (response.audio.length.isOdd) {
          throw const SipLeaseFailure('INVALID_PCM');
        }
        return response.audio.isEmpty
            ? const []
            : [DomesticModelAudio(response.audio)];
      }
      if (response.event >= 650 && response.event <= 655) {
        final transcript = response.event <= 652
            ? _transcript.source(response.text, response.event)
            : _transcript.translation(response.text, response.event);
        return [
          if (transcript != null) DomesticModelTranscript(transcript),
          if (response.event == 655) const DomesticModelAudioDone(),
        ];
      }
      return const [];
    } catch (_) {
      return const [DomesticModelError('MODEL_PROTOCOL_ERROR')];
    }
  }

  static String _language(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-').split('-').first;
}
