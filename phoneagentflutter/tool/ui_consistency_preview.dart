import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'previews/shell_preview.dart';

/// Ordinary rendering for full-device UI capture, without a test binding.
/// Business ports remain synthetic; About reads this host’s installed metadata.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  const signedIn = bool.fromEnvironment('UI_START_SIGNED_IN');
  runApp(
    const ShellPreviewPage(
      startSignedIn: signedIn,
      formalClone: bool.fromEnvironment('UI_FORMAL_CLONE'),
      nativeSystemVoices: bool.fromEnvironment('UI_NATIVE_SYSTEM_VOICES'),
      initializeIdentity: !signedIn,
    ),
  );
}
