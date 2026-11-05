import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/service_routes.dart';
import '../../../core/network/signing/c1_transport.dart';

class SignedHomeAssetSource {
  SignedHomeAssetSource(this.config, this.signing, {Dio? client})
    : client = client ?? Dio() {
    this.client.options.connectTimeout = const Duration(seconds: 20);
    this.client.options.receiveTimeout = const Duration(seconds: 20);
  }
  final AppConfig config;
  final C1Transport signing;
  final Dio client;
  void close() => client.close(force: true);
  Future<Uint8List> load(String url) async {
    final uri = Uri.parse(url),
        base = config.sdkApiBaseUri ?? config.apiBaseUri;
    if (base == null ||
        uri.origin != base.origin ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith(
          '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/home-config/assets/',
        )) {
      throw const FormatException('Invalid home asset');
    }
    final signed = await signing.prepare(
      uri,
      service: ApiService.sdk,
      method: 'GET',
      token: '',
    );
    final response = await client.getUri<ResponseBody>(
      uri,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        validateStatus: (_) => true,
        headers: signed.$2,
      ),
    );
    final data = response.data;
    if (response.statusCode != 200 ||
        data == null ||
        !{
          'image/png',
          'image/jpeg',
          'image/webp',
          'image/gif',
        }.contains(response.headers.value('content-type')?.split(';').first)) {
      throw const FormatException('Invalid home image');
    }
    final output = BytesBuilder();
    await for (final chunk in data.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (output.length + chunk.length > 5 * 1024 * 1024) {
        throw const FormatException('Home asset too large');
      }
      output.add(chunk);
    }
    return output.takeBytes();
  }
}
