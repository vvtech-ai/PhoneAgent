enum SystemDialResult { opened, unsupported, failed, invalid }

abstract interface class SystemDialer {
  Future<SystemDialResult> open(String number);
}
