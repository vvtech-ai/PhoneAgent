class OriginalAudioSettings {
  const OriginalAudioSettings({
    this.enabled = false,
    this.gain = 50,
    this.volume = 100,
  });
  final bool enabled;
  final int gain, volume;
  static int level(int value, int max) =>
      ((value.clamp(0, max) + 5) ~/ 10) * 10;
  OriginalAudioSettings copy({bool? enabled, int? gain, int? volume}) =>
      OriginalAudioSettings(
        enabled: enabled ?? this.enabled,
        gain: level(gain ?? this.gain, 50),
        volume: level(volume ?? this.volume, 100),
      );
  Map<String, Object> toJson() => {
    'version': 1,
    'enabled': enabled,
    'gain': gain,
    'volume': volume,
  };
  static OriginalAudioSettings fromJson(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['enabled'] is! bool ||
        value['gain'] is! int ||
        value['volume'] is! int) {
      throw const FormatException('Invalid original audio preferences');
    }
    return OriginalAudioSettings(
      enabled: value['enabled'] as bool,
      gain: level(value['gain'] as int, 50),
      volume: level(value['volume'] as int, 100),
    );
  }
}

abstract interface class OriginalAudioStore {
  Future<OriginalAudioSettings> read();
  Future<void> write(OriginalAudioSettings value);
}
