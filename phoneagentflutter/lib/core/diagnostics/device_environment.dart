/// Installed app and public device metadata captured together by the native host.
class DeviceEnvironment {
  const DeviceEnvironment({
    required this.appVersion,
    required this.appBuild,
    required this.osName,
    required this.osVersion,
    required this.brand,
    required this.manufacturer,
    required this.model,
    this.hardwareModel = '',
    this.apiLevel,
  });
  final String appVersion, osName, osVersion, brand, manufacturer, model;
  final String hardwareModel;
  final int appBuild;
  final int? apiLevel;

  Map<String, Object> toJson() => {
    'schema': 1,
    'available': true,
    'appVersion': appVersion,
    'appBuild': appBuild,
    'osName': osName,
    'osVersion': osVersion,
    'brand': brand,
    'manufacturer': manufacturer,
    'model': model,
    if (hardwareModel.isNotEmpty) 'hardwareModel': hardwareModel,
    if (apiLevel != null) 'apiLevel': apiLevel!,
  };
}
