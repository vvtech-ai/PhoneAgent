import 'dart:math';

/// A recording submission owns one stable ID; observers never generate one.
String cloneGenerationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
