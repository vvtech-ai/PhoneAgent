/// Thin platform port: raw mono PCM16LE/16k -> genuine AAC/M4A at 48kbit/s.
/// Implementations must reject files outside the application's private root.
abstract interface class DomesticRecordingEncoder {
  Future<void> encode({required String pcmPath, required String m4aPath});
}
