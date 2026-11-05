import '../../domain/commerce_repository.dart';

/// Keeps a successful read when the other commerce resource fails.
class CatalogReadResult<T> {
  const CatalogReadResult(this.value, this.error);
  final T? value;
  final String error;

  static Future<CatalogReadResult<T>> read<T>(
    Future<T> Function() read,
    String fallback,
  ) async {
    try {
      return CatalogReadResult(await read(), '');
    } catch (error) {
      return CatalogReadResult(
        null,
        error is CommerceFailure ? error.message : fallback,
      );
    }
  }
}
