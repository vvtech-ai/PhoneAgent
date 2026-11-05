import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/feedback/data/legacy_rating_draft_codec.dart';

void main() {
  test('v65 fields, partial input and retry key survive without trimming', () {
    final result = LegacyRatingDraftCodec.decode(
      jsonEncode({
        'taskUnderstanding': 4,
        'aiCallPerformance': 2,
        'cloneVoicePerformance': 3,
        'cloneVoiceNotEvaluated': false,
        'taskCompletion': 5,
        'suggestion': '  合成建议\n',
        'submissionKey': 'f0706457-6983-4ff6-ab06-69ee137ecbfc',
        'baseSubmissionVersion': null,
      }),
    )!;
    expect(result.draft.taskUnderstanding, 4);
    expect(result.draft.aiCallPerformance, 2);
    expect(result.draft.cloneVoicePerformance, 3);
    expect(result.draft.taskCompletion, 5);
    expect(result.draft.cloneVoiceNotEvaluated, false);
    expect(result.draft.suggestion, '  合成建议\n');
    expect(result.submissionKey, 'f0706457-6983-4ff6-ab06-69ee137ecbfc');
    final partial = LegacyRatingDraftCodec.decode('{}')!;
    expect(partial.draft.taskUnderstanding, isNull);
    expect(partial.draft.cloneVoiceNotEvaluated, false);
    expect(partial.submissionKey, isEmpty);
    expect(LegacyRatingDraftCodec.decode(null), isNull);
  });

  test('over-300 unsent suggestion remains editable rather than truncated', () {
    final text = '界' * 301;
    final result = LegacyRatingDraftCodec.decode(
      jsonEncode({'suggestion': text}),
    )!;
    expect(result.draft.suggestion, text);
    expect(result.draft.valid(cloneVoiceAvailable: false), false);
  });

  test('malformed types/ranges/envelopes fail without private text', () {
    for (final raw in [
      '',
      'null',
      '[]',
      'private malformed',
      '{"taskUnderstanding":0}',
      '{"taskCompletion":6}',
      '{"aiCallPerformance":2.5}',
      '{"cloneVoicePerformance":"3"}',
      '{"cloneVoiceNotEvaluated":"false"}',
      '{"suggestion":123}',
      '{"submissionKey":true}',
      jsonEncode({'submissionKey': 'x\nprivate'}),
    ]) {
      expect(
        () => LegacyRatingDraftCodec.decode(raw),
        throwsA(
          isA<FormatException>().having(
            (e) => e.toString(),
            'sanitized',
            'FormatException: Legacy rating draft unavailable',
          ),
        ),
      );
    }
  });

  test('UTF8 limit rejects without partial recovery', () {
    expect(
      () => LegacyRatingDraftCodec.decode(
        jsonEncode({'suggestion': '界' * 23000}),
      ),
      throwsFormatException,
    );
    expect(
      () => LegacyRatingDraftCodec.decode(' ' * 65537),
      throwsFormatException,
    );
  });
}
