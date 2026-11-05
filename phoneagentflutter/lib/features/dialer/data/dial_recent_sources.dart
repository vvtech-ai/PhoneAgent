import '../domain/dial_recent_source.dart';

/// Honest migration boundary until CallLog and translation archive are wired.
class UnavailableDialRecentSource implements DialRecentCallSource {
  const UnavailableDialRecentSource(this.access);
  final DialRecentAccess access;
  @override
  Future<DialRecentSnapshot> load() async => DialRecentSnapshot(access);
}
