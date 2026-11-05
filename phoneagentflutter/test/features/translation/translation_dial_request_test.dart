import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_request.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/settings/domain/original_audio_settings.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_completion_preview_controller.dart';

void main() {
  test(
    'snapshot preserves selected node/model/languages and original audio',
    () {
      var preferences = const TranslationPreferences(
        provider: 'OPENAI',
        region: 'JP',
        caller: 'fr',
        peer: 'ja',
      );
      final dial = TranslationDialRequest(
        rawNumber: '+1 202 555 0123 ext 12',
        countryIso: 'US',
        displayName: '合成联系人',
        preferences: preferences,
      );
      preferences = preferences.copy(
        provider: 'GEMINI',
        region: 'US',
        peer: 'en',
      );
      final payload = dial
          .toCreateRequest(
            userId: 'synthetic',
            originalAudio: const OriginalAudioSettings(
              enabled: true,
              gain: 30,
              volume: 70,
            ),
          )
          .toJson();
      expect(dial.serviceRegion, 'JP');
      expect(dial.targetLabel, '合成联系人');
      expect(payload['merchantPhone'], '+12025550123');
      expect(payload['realtimeProvider'], 'openai');
      expect(payload['userLanguage'], 'fr');
      expect(payload['merchantLanguage'], 'ja');
      expect(payload['originalAudioEnabled'], true);
      expect(payload['originalAudioPercent'], 30);
      expect(payload['originalAudioVolumePercent'], 70);
      expect(payload.containsKey('extension'), false);
      expect(payload.containsKey('billingSessionId'), false);
      expect(preferences.region, 'US');
    },
  );
  test('disabled original audio sends zero gain; blank name uses phone', () {
    final dial = TranslationDialRequest(
      rawNumber: '2025550123',
      countryIso: 'US',
      displayName: ' ',
      preferences: const TranslationPreferences(),
    );
    expect(dial.targetLabel, '+12025550123');
    expect(
      dial
          .toCreateRequest(
            userId: 'synthetic',
            originalAudio: const OriginalAudioSettings(),
          )
          .toJson()['originalAudioPercent'],
      0,
    );
  });
  test('invalid number, node, domestic provider and ordinary mode reject', () {
    for (final preferences in [
      const TranslationPreferences(enabled: false),
      const TranslationPreferences(provider: 'DOUBAO'),
      const TranslationPreferences(region: 'CN'),
    ]) {
      expect(
        () => TranslationDialRequest(
          rawNumber: '+12025550123',
          countryIso: 'US',
          displayName: '',
          preferences: preferences,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => TranslationDialRequest(
        rawNumber: '12',
        countryIso: 'US',
        displayName: '',
        preferences: const TranslationPreferences(),
      ),
      throwsFormatException,
    );
  });
  test(
    'confirmation snapshot reaches same session and original account record',
    () async {
      final completion = TranslationCompletionPreviewController();
      completion.originalAudio = const OriginalAudioSettings(
        enabled: true,
        gain: 40,
      );
      final dial = TranslationDialRequest(
        rawNumber: '+12025550123',
        countryIso: 'US',
        displayName: '合成新目标',
        preferences: const TranslationPreferences(
          caller: 'fr',
          peer: 'ja',
          provider: 'OPENAI',
          region: 'JP',
        ),
      );
      final controller = completion.createDial(dial);
      final start = controller.start();
      await Future<void>.delayed(Duration.zero);
      final fixture = completion.activeFixture!;
      fixture.ready();
      await start;
      expect(fixture.lastCreate!.phone, '+12025550123');
      expect(fixture.lastCreate!.userLanguage, 'fr');
      expect(fixture.lastCreate!.merchantLanguage, 'ja-JP');
      expect(fixture.lastCreate!.originalAudioPercent, 40);
      fixture.connected();
      final loaded = Completer<void>();
      final remove = completion.recent.addListener((state) {
        if (!state.loading && state.records.isNotEmpty && !loaded.isCompleted) {
          loaded.complete();
        }
      });
      await controller.hangup();
      await completion.recorder.idle;
      await loaded.future.timeout(const Duration(seconds: 2));
      remove();
      expect(
        completion.recentState.records.single.restorablePhone,
        '+12025550123',
      );
      expect(completion.recentState.records.single.callerLanguage, 'fr');
      expect(completion.recentState.records.single.countryIso, 'US');
      expect(fixture.creates, 1);
      expect(fixture.hangups, 1);
      controller.dispose();
      completion.dispose();
    },
  );
}
