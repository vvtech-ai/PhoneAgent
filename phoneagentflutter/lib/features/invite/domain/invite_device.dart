import 'dart:typed_data';

abstract interface class InviteDevice {
  Future<void> copy(String text);
  Future<bool> savePoster(Uint8List png);
  Future<String?> initialLink();
  Stream<String> get links;
}
