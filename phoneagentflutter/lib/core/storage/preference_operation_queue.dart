/// Serializes one persisted key across store instances in this isolate.
abstract final class PreferenceOperationQueue {
  static final _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() operation) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[key] = tail;
    tail.then((_) {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    return result;
  }
}
