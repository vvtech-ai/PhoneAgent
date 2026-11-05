import 'package:dio/dio.dart';

/// Native transport already exposes incremental response bytes.
Dio createStreamClient() => Dio();
