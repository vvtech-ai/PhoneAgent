import '../service_routes.dart';

class C1Credentials {
  const C1Credentials({
    required this.apiKey,
    required this.secret,
    required this.deviceId,
    required this.clientContext,
  });
  final String apiKey, secret, deviceId, clientContext;
}

abstract interface class C1CredentialSource {
  Future<C1Credentials> read(ApiService service);
}
