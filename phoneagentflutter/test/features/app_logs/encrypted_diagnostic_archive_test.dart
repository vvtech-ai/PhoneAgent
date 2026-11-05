import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_archive.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/app_logs/data/diagnostic_archive_cipher.dart';
import 'package:phone_agent/features/app_logs/data/directory_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/encrypted_diagnostic_files.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DirectoryDiagnosticFiles raw;
  late SecureDiagnosticKey keys;
  late DiagnosticArchive archive;
  const scope = 'dev|synthetic-api|synthetic-user';
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('phoneagent-encrypted-test-');
    raw = DirectoryDiagnosticFiles(root, scope);
    keys = SecureDiagnosticKey(scope);
    archive = DiagnosticArchive(
      EncryptedDiagnosticFiles(raw, scope, keys.load),
      maxFileBytes: DiagnosticArchiveCipher.maxPlainBytes,
    );
  });
  tearDown(() => root.delete(recursive: true));

  DiagnosticEvent event() => DiagnosticEvent(
    operation: DiagnosticOperation.agentSignal,
    result: DiagnosticResult.failed,
    failureKind: DiagnosticFailureKind.timeout,
    sessionId: 'ca51dfce-4f73-4324-852a-780cdf1d619d',
  );

  test(
    'real directory has only authenticated ciphertext, reopening preserves events',
    () async {
      await archive.append([event()]);
      for (final name in await raw.names()) {
        final text = (await raw.read(name))!;
        expect(text, startsWith('v1.'));
        expect(text, isNot(contains('agentSignal')));
        expect(text, isNot(contains('ca51dfce')));
        expect(text, isNot(contains('sequence')));
      }
      final reopened = DiagnosticArchive(
        EncryptedDiagnosticFiles(raw, scope, keys.load),
        maxFileBytes: DiagnosticArchiveCipher.maxPlainBytes,
      );
      expect(
        (await reopened.snapshot()).events.single.failureKind,
        DiagnosticFailureKind.timeout,
      );
      await reopened.acknowledge(1);
      expect((await reopened.snapshot()).events, isEmpty);
    },
  );

  test(
    'random nonce makes identical plaintext produce different ciphertext',
    () async {
      final key = List<int>.generate(32, (i) => i);
      final first = await DiagnosticArchiveCipher.encrypt(
        'synthetic',
        key,
        'owner|file',
      );
      final second = await DiagnosticArchiveCipher.encrypt(
        'synthetic',
        key,
        'owner|file',
      );
      expect(first, isNot(second));
      expect(
        await DiagnosticArchiveCipher.decrypt(first, key, 'owner|file'),
        'synthetic',
      );
    },
  );

  test(
    'cipher binds scope and filename, rejects tamper and wrong key',
    () async {
      final key = List<int>.filled(32, 1);
      final value = await DiagnosticArchiveCipher.encrypt(
        'synthetic',
        key,
        'owner-a|index',
      );
      for (final binding in ['owner-b|index', 'owner-a|other-file']) {
        await expectLater(
          DiagnosticArchiveCipher.decrypt(value, key, binding),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      }
      await expectLater(
        DiagnosticArchiveCipher.decrypt(
          value,
          List<int>.filled(32, 2),
          'owner-a|index',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final bytes = base64Decode(value.substring(3));
      bytes[bytes.length - 1] ^= 1;
      await expectLater(
        DiagnosticArchiveCipher.decrypt(
          'v1.${base64Encode(bytes)}',
          key,
          'owner-a|index',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test('envelope overhead fits actual five MiB limit', () async {
    final key = List<int>.filled(32, 7);
    final text = 'x' * DiagnosticArchiveCipher.maxPlainBytes;
    final encoded = await DiagnosticArchiveCipher.encrypt(
      text,
      key,
      'scope|file',
    );
    expect(encoded.length, lessThanOrEqualTo(5 * 1024 * 1024));
    expect(
      await DiagnosticArchiveCipher.decrypt(encoded, key, 'scope|file'),
      text,
    );
    await expectLater(
      DiagnosticArchiveCipher.encrypt('${text}x', key, 'scope|file'),
      throwsStateError,
    );
  });

  test(
    'missing key with existing data fails without replacing ciphertext',
    () async {
      await archive.append([event()]);
      final before = await raw.read('index.json');
      await const FlutterSecureStorage().delete(key: keys.key);
      await expectLater(archive.append([event()]), throwsStateError);
      expect(await raw.read('index.json'), before);
      expect(await const FlutterSecureStorage().read(key: keys.key), isNull);
    },
  );

  test('invalid key never regenerates or overwrites persisted value', () async {
    await const FlutterSecureStorage().write(
      key: keys.key,
      value: base64Encode([1, 2]),
    );
    await expectLater(archive.snapshot(), throwsFormatException);
    expect(
      await const FlutterSecureStorage().read(key: keys.key),
      base64Encode([1, 2]),
    );
    expect(await raw.names(), isEmpty);
  });

  test(
    'simultaneous factory instances create one key under directory transaction',
    () async {
      final other = DiagnosticArchive(
        EncryptedDiagnosticFiles(
          DirectoryDiagnosticFiles(root, scope),
          scope,
          SecureDiagnosticKey(scope).load,
        ),
        maxFileBytes: DiagnosticArchiveCipher.maxPlainBytes,
      );
      await Future.wait([
        archive.append([event()]),
        other.append([event()]),
      ]);
      expect((await archive.snapshot()).events, hasLength(2));
      expect((await const FlutterSecureStorage().readAll()).length, 1);
    },
  );

  test('ciphertext renamed to another accepted filename is rejected', () async {
    await archive.append([event()]);
    final name = (await raw.names()).singleWhere(
      (name) => name.endsWith('.jsonl'),
    );
    final data = await raw.read(name);
    await raw.replace('index.json', data!);
    await expectLater(
      archive.snapshot(),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    expect(await raw.read('index.json'), data);
  });

  test(
    'malformed envelope and unexpected plaintext are never silently accepted',
    () async {
      final key = List<int>.filled(32, 1);
      for (final value in ['{}', 'v2.AAAA', 'v1.AAAA', 'v1.!!']) {
        await expectLater(
          DiagnosticArchiveCipher.decrypt(value, key, 'binding'),
          throwsFormatException,
        );
      }
    },
  );
}
