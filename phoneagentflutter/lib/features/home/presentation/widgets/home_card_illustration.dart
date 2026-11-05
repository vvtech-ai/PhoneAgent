import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/home_asset_providers.dart';

class HomeCardIllustration extends ConsumerWidget {
  const HomeCardIllustration({
    required this.cardId,
    required this.url,
    required this.enabled,
    super.key,
  });
  final String cardId;
  final String? url;
  final bool enabled;

  static const _names = {
    'restaurant_booking': 'restaurant_booking',
    'meeting_invite': 'meeting_invite',
    'meeting_invite_v2': 'meeting_invite',
    'apology': 'apology',
    'event_invite': 'event_invite',
    'move_car': 'move_car',
    'sales_promotion': 'sales_promotion',
    'simultaneous_interpretation': 'simultaneous_interpretation',
  };

  Widget _fallback() {
    final name = _names[cardId];
    return name == null
        ? const SizedBox.shrink()
        : Image.asset(
            'assets/images/shell/home_card_$name.png',
            fit: BoxFit.contain,
          );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ExcludeSemantics(
    child: Opacity(
      opacity: enabled ? 0.5 : 0.3,
      child: url == null || url!.trim().isEmpty
          ? _fallback()
          : Uri.tryParse(url!)?.path.contains('/api/home-config/assets/') ==
                true
          ? ref
                .watch(homeAssetBytesProvider(url!))
                .when(
                  data: (bytes) => Image.memory(bytes, fit: BoxFit.contain),
                  loading: _fallback,
                  error: (_, __) => _fallback(),
                )
          : Image.network(
              url!,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _fallback(),
              errorBuilder: (_, __, ___) => _fallback(),
            ),
    ),
  );
}
