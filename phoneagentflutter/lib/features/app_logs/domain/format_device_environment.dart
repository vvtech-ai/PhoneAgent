import '../../../../core/diagnostics/device_environment.dart';

/// The SDK log and feedback columns both accept at most 512 UTF-16 code units.
String formatDeviceEnvironment(DeviceEnvironment value) {
  final platform = value.osName == 'Android' ? 'android' : 'iOS';
  final api = value.apiLevel == null ? '' : ' (API ${value.apiLevel})';
  return [
    'Flutter $platform / ${_field(value.appVersion, 40)}(${value.appBuild})',
    '${value.osName} ${_field(value.osVersion, 48)}$api',
    'brand=${_field(value.brand, 48)}',
    'manufacturer=${_field(value.manufacturer, 48)}',
    'model=${_field(value.model, 96)}',
    'hardware=${_field(value.hardwareModel, 64)}',
  ].join('; ');
}

String _field(String text, int limit) {
  final clean = text.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
  if (clean.isEmpty) return 'unavailable';
  var length = 0;
  return String.fromCharCodes(
    clean.runes.takeWhile((rune) {
      length += rune > 0xffff ? 2 : 1;
      return length <= limit;
    }),
  );
}
