import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/document_submission_context.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';

void main() {
  const context = DocumentSubmissionContext(
    sessionId: 'synthetic-session',
    generation: 4,
    voiceMode: true,
    initialSource: ContactInputSource.typed,
  );
  test(
    'document parse is accepted only for its original session and generation',
    () {
      expect(context.accepts('synthetic-session', 4), isTrue);
      expect(context.accepts('other-session', 4), isFalse);
      expect(context.accepts('synthetic-session', 5), isFalse);
    },
  );
  test(
    'first voice document restores voice input without requiring prior speech',
    () {
      expect(
        context.submissionSource(ContactInputSource.typed, voiceMode: true),
        ContactInputSource.asr,
      );
    },
  );
  test(
    'manual mode change during parsing preserves the selected text mode',
    () {
      expect(
        context.submissionSource(ContactInputSource.typed, voiceMode: false),
        ContactInputSource.typed,
      );
      expect(
        context.submissionSource(ContactInputSource.asr, voiceMode: false),
        ContactInputSource.typed,
      );
    },
  );
  test('explicit source change during parsing remains authoritative', () {
    const text = DocumentSubmissionContext(
      sessionId: 's',
      generation: 1,
      voiceMode: false,
      initialSource: ContactInputSource.unknown,
    );
    expect(
      text.submissionSource(ContactInputSource.asr, voiceMode: false),
      ContactInputSource.asr,
    );
    expect(
      text.submissionSource(ContactInputSource.unknown, voiceMode: false),
      ContactInputSource.typed,
    );
  });
}
