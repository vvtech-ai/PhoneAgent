import '../domain/outbound_number.dart';

/// Explicit in-memory fixture; never contains an account or network client.
class PreviewOutboundNumberRepository implements OutboundNumberRepository {
  PreviewOutboundNumberRepository({String number = ''})
    : value = OutboundNumber(number, configured: number.isNotEmpty);
  OutboundNumber value;
  bool failRead = false, failWrite = false;
  int reads = 0, saves = 0, deletes = 0;
  @override
  Future<OutboundNumber> load() async {
    reads++;
    if (failRead) throw StateError('Synthetic read failure');
    return OutboundNumber(value.number, configured: value.configured);
  }

  @override
  Future<OutboundNumber> save(String number) async {
    saves++;
    if (failWrite) throw StateError('Synthetic write failure');
    return value = OutboundNumber(number, configured: number.isNotEmpty);
  }

  @override
  Future<OutboundNumber> delete() async {
    deletes++;
    if (failWrite) throw StateError('Synthetic write failure');
    return value = const OutboundNumber('', configured: false);
  }
}
