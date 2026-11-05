enum DiagnosticPcmPhase {
  category,
  activation,
  route,
  attach,
  connect,
  engineStart,
  playerPlay,
  duplexAcquire,
  release,
  unknown,
}

enum DiagnosticPcmDomain { osStatus, audioSession, cocoa, other }

enum DiagnosticPcmRoute { speaker, receiver, bluetooth, wired, other, none }

/// Native exception text, device names and arbitrary fields never enter exports.
class DiagnosticPcmDetails {
  const DiagnosticPcmDetails({
    required this.phase,
    required this.domain,
    required this.code,
    required this.appState,
    required this.route,
    required this.engineRunning,
    required this.outputPresent,
    this.outputId = '',
  });
  final DiagnosticPcmPhase phase;
  final DiagnosticPcmDomain domain;
  final DiagnosticPcmRoute route;
  final int code, appState;
  final bool engineRunning, outputPresent;
  final String outputId;

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.firstWhere((e) => e.name == name, orElse: () => fallback);
  static DiagnosticPcmDetails? parse(Object? value) {
    if (value is! Map) return null;
    final id = value['outputId'];
    return DiagnosticPcmDetails(
      phase: _enum(
        DiagnosticPcmPhase.values,
        value['phase'],
        DiagnosticPcmPhase.unknown,
      ),
      domain: _enum(
        DiagnosticPcmDomain.values,
        value['domain'],
        DiagnosticPcmDomain.other,
      ),
      route: _enum(
        DiagnosticPcmRoute.values,
        value['route'],
        DiagnosticPcmRoute.other,
      ),
      code: value['code'] is int
          ? (value['code'] as int).clamp(-2147483648, 2147483647)
          : 0,
      appState: value['appState'] is int
          ? (value['appState'] as int).clamp(-1, 2)
          : -1,
      engineRunning: value['engineRunning'] == true,
      outputPresent: value['outputPresent'] == true,
      outputId:
          id is String && RegExp(r'^[0-9]{10,20}-[0-9]{1,10}$').hasMatch(id)
          ? id
          : '',
    );
  }

  Map<String, Object> toJson() => {
    'phase': phase.name,
    'domain': domain.name,
    'code': code.clamp(-2147483648, 2147483647),
    'appState': appState.clamp(-1, 2),
    'route': route.name,
    'engineRunning': engineRunning,
    'outputPresent': outputPresent,
    if (RegExp(r'^[0-9]{10,20}-[0-9]{1,10}$').hasMatch(outputId))
      'outputId': outputId,
  };
}
