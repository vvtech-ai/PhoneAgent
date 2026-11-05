enum TranslationEnvironmentState {
  pending,
  available,
  degraded,
  unavailable,
  notApplicable;

  String get label => switch (this) {
    pending => '检测中',
    available => '可用',
    degraded => '较弱',
    unavailable => '不可用',
    notApplicable => '不适用',
  };
}

/// Read-only projection of the native versioned environment protocol.
class TranslationCallEnvironment {
  const TranslationCallEnvironment({
    this.version = -1,
    this.network = TranslationEnvironmentState.pending,
    this.sip = TranslationEnvironmentState.pending,
    this.model = TranslationEnvironmentState.pending,
    this.riskMessage = '',
  });
  final int version;
  final TranslationEnvironmentState network, sip, model;
  final String riskMessage;

  TranslationEnvironmentState get overall {
    final applicable = [
      network,
      sip,
      model,
    ].where((state) => state != TranslationEnvironmentState.notApplicable);
    if (applicable.isEmpty) return TranslationEnvironmentState.notApplicable;
    int severity(TranslationEnvironmentState state) => switch (state) {
      TranslationEnvironmentState.notApplicable => 0,
      TranslationEnvironmentState.available => 1,
      TranslationEnvironmentState.pending => 2,
      TranslationEnvironmentState.degraded => 3,
      TranslationEnvironmentState.unavailable => 4,
    };
    return applicable.reduce((a, b) => severity(a) >= severity(b) ? a : b);
  }

  TranslationCallEnvironment apply(Map<String, Object?> patch) {
    final rawVersion = patch['version'];
    if (rawVersion is! num || !rawVersion.isFinite || rawVersion < 0) {
      return this;
    }
    final nextVersion = rawVersion.toInt();
    if (nextVersion < version) return this;
    TranslationEnvironmentState? component(String name) {
      final raw = patch[name];
      if (raw is! Map) return null;
      final value = raw['state'];
      if (value is! String) return null;
      return switch (value.trim().toLowerCase()) {
        'pending' => TranslationEnvironmentState.pending,
        'available' => TranslationEnvironmentState.available,
        'degraded' => TranslationEnvironmentState.degraded,
        'unavailable' => TranslationEnvironmentState.unavailable,
        'not_applicable' ||
        'not-applicable' => TranslationEnvironmentState.notApplicable,
        _ => null,
      };
    }

    final risk = patch['riskMessage'];
    return TranslationCallEnvironment(
      version: nextVersion,
      network: component('network') ?? network,
      sip: component('sip') ?? sip,
      model: component('model') ?? model,
      riskMessage: risk is String && risk.trim().isNotEmpty
          ? risk.trim()
          : riskMessage,
    );
  }
}
