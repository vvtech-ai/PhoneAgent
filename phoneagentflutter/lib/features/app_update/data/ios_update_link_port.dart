import 'package:flutter/services.dart';
import '../domain/ios_update_link.dart';

class IosUpdateLinkPort {
  const IosUpdateLinkPort({
    this.channel = const MethodChannel('com.vvtech.phone_agent/ios_update'),
  });
  final MethodChannel channel;

  Future<void> open(String link) async {
    final opened = await channel.invokeMethod<bool>(
      'open',
      IosUpdateLink.resolve(link),
    );
    if (opened != true) throw StateError('Unable to open iOS update link');
  }
}
