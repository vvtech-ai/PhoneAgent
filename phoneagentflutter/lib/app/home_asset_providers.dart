import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/data/signed_home_asset_source.dart';
import 'app_providers.dart';
import 'request_signing_providers.dart';

final homeAssetSourceProvider = Provider.autoDispose<SignedHomeAssetSource>((
  ref,
) {
  final source = SignedHomeAssetSource(
    ref.watch(appConfigProvider),
    ref.watch(requestSigningProvider),
  );
  ref.onDispose(source.close);
  return source;
});
final homeAssetBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, url) => ref.watch(homeAssetSourceProvider).load(url),
    );
