import 'dart:convert';
import 'package:crypto/crypto.dart';

String contentHash(String text) => sha256.convert(utf8.encode(text)).toString();
