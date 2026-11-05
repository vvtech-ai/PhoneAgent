import 'dart:io';
import 'package:path/path.dart' as paths;

/// Owns only newly created temporary recording fixtures, never user directories.
class RecordingFileFixture {
  final _directories = <Directory, String>{};
  final _links = <Link>[];

  Future<Directory> directory(String prefix) async {
    final root = await Directory.systemTemp.createTemp(prefix);
    final actual = await root.resolveSymbolicLinks();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    if (!paths.isWithin(temp, actual)) {
      throw StateError('Recording fixture is outside system temp');
    }
    // Use the same canonical root as production recording paths on macOS.
    final owned = Directory(actual);
    _directories[owned] = actual;
    return owned;
  }

  bool _owned(String path) => _directories.values.any(
    (root) => paths.equals(root, path) || paths.isWithin(root, path),
  );

  Future<void> _checkLink(String path, String target) async {
    if (!_directories.keys.any(
          (root) =>
              paths.isWithin(paths.absolute(root.path), paths.absolute(path)),
        ) ||
        !_owned(await Directory(paths.dirname(path)).resolveSymbolicLinks()) ||
        !_owned(await File(target).resolveSymbolicLinks())) {
      throw StateError('Recording redirect is outside owned fixtures');
    }
  }

  Future<void> directoryRedirect(String path, Directory target) async {
    await _checkLink(path, target.path);
    _links.add(Link(path));
    if (Platform.isWindows) {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'New-Item -ItemType Junction -Path $env:RECORDING_FIXTURE_LINK -Target $env:RECORDING_FIXTURE_TARGET -ErrorAction Stop | Out-Null',
        ],
        environment: {
          'RECORDING_FIXTURE_LINK': path,
          'RECORDING_FIXTURE_TARGET': target.path,
        },
      );
      if (result.exitCode != 0) {
        throw FileSystemException(
          'Directory junction creation failed (exit ${result.exitCode})',
          path,
        );
      }
    } else {
      await Link(path).create(target.path);
    }
    if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.link ||
        await Directory(path).resolveSymbolicLinks() !=
            await target.resolveSymbolicLinks()) {
      throw StateError('Recording directory redirect was not created');
    }
  }

  /// False means only the verified Windows privilege error, not a passing test.
  Future<bool> fileSymlink(String path, File target) async {
    await _checkLink(path, target.path);
    _links.add(Link(path));
    try {
      await Link(path).create(target.path);
    } on FileSystemException catch (error) {
      if (Platform.isWindows && error.osError?.errorCode == 1314) return false;
      rethrow;
    }
    return true;
  }

  Future<void> close() async {
    // Unlink every redirect before recursively removing any owned directory.
    for (final link in _links.reversed) {
      final type = await FileSystemEntity.type(link.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.link) {
        throw StateError('Recording fixture redirect changed type');
      }
      await link.delete();
    }
    _links.clear();
    final temp = await Directory.systemTemp.resolveSymbolicLinks();
    for (final entry in _directories.entries.toList().reversed) {
      final actual = await entry.key.resolveSymbolicLinks();
      if (!paths.equals(actual, entry.value) ||
          !paths.isWithin(temp, actual) ||
          await FileSystemEntity.type(entry.key.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        throw StateError('Refusing cleanup outside owned temporary directory');
      }
      await entry.key.delete(recursive: true);
    }
    _directories.clear();
  }
}
