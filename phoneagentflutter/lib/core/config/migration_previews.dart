import 'package:flutter/foundation.dart';

/// Fixtures are reachable only in Debug; never gates original developer tools.
const migrationPreviewsEnabled =
    kDebugMode &&
    bool.fromEnvironment('ENABLE_MIGRATION_PREVIEWS', defaultValue: true);
