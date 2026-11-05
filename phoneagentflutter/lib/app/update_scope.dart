import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/config/app_config.dart';

String updateInstallScope(
  AppConfig config,
  String? accountId,
  String packageName,
) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          config.environment?.name,
          config.apiBaseUri?.toString(),
          accountId,
          packageName,
        ]),
      ),
    )
    .toString();
