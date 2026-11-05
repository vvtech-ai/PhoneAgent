/// Keeps valid user choices; only fallback choices avoid equal peers when possible.
({String caller, String peer}) normalizeTranslationLanguages({
  required Iterable<String> enabledCodes,
  required String caller,
  required String peer,
  required String defaultCaller,
  required String defaultPeer,
  Set<String>? sourceCodes,
  Set<String>? targetCodes,
}) {
  final codes = enabledCodes.toList();
  String preferred(
    String selected,
    String fallback,
    Set<String>? supported, {
    String avoid = '',
  }) {
    final available = codes.where(
      (code) => supported == null || supported.contains(code),
    );
    if (available.contains(selected)) return selected;
    if (available.contains(fallback) && fallback != avoid) return fallback;
    return available.where((code) => code != avoid).firstOrNull ??
        (available.contains(fallback) ? fallback : available.firstOrNull) ??
        '';
  }

  final source = preferred(caller, defaultCaller, sourceCodes);
  return (
    caller: source,
    peer: preferred(peer, defaultPeer, targetCodes, avoid: source),
  );
}
