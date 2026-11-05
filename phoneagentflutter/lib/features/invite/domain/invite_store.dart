abstract interface class InviteStore {
  Future<Map<String, dynamic>> read(String slot);
  Future<void> write(String slot, Map<String, dynamic> value);
}

class MemoryInviteStore implements InviteStore {
  final _values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> read(String slot) async =>
      Map.of(_values[slot] ?? {});
  @override
  Future<void> write(String slot, Map<String, dynamic> value) async {
    _values[slot] = Map.of(value);
  }
}
