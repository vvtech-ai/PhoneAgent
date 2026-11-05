import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Handwritten Dart files fit the default 500 line budget', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>();
    for (final file in files.where((f) => f.path.endsWith('.dart'))) {
      expect(
        file.readAsLinesSync().length,
        lessThanOrEqualTo(
          // Reviewed single-responsibility exceptions; see file_exceptions.md.
          switch (file.path.replaceAll('\\', '/')) {
            'lib/features/conversation/presentation/controller/conversation_controller.dart' =>
              527,
            'lib/features/calls/presentation/controller/conversation_call_controller.dart' =>
              507,
            'lib/features/translation/domain/sip/domestic_sip_media.dart' =>
              504,
            _ => 500,
          },
        ),
        reason: file.path,
      );
    }
  });

  test('Pure configuration has no framework or transport dependency', () {
    final source = File('lib/core/config/app_config.dart').readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('package:dio')));
  });

  test('Domain and audio policies have no framework or device dependency', () {
    final files = Directory('lib').listSync(recursive: true).whereType<File>();
    final directives = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
    for (final file in files.where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.contains('/domain/') && !path.startsWith('lib/core/audio/')) {
        continue;
      }
      for (final directive in directives.allMatches(file.readAsStringSync())) {
        final dependency = directive.group(1)!;
        expect(dependency, isNot(startsWith('package:')), reason: path);
        expect(dependency, isNot(contains('/data/')), reason: path);
        expect(dependency, isNot(contains('/presentation/')), reason: path);
        expect(
          dependency,
          isNot(isIn(['dart:io', 'dart:ui', 'dart:ffi'])),
          reason: path,
        );
      }
    }
  });

  test('Portrait and platform identities remain explicit', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final xcode = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(android, contains('android:screenOrientation="portrait"'));
    expect(gradle, contains('applicationId = "com.vvtech.aiassistant"'));
    expect(
      gradle,
      contains('variant.applicationId.set("com.vvtech.aiassistant.dev")'),
    );
    expect(gradle, isNot(contains('applicationIdSuffix =')));
    expect(ios, isNot(contains('UIInterfaceOrientationLandscape')));
    expect(
      xcode,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.chaken.phoneagent.test;'),
    );
    expect(
      xcode,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.chaken.phoneagent;'),
    );
  });
}
