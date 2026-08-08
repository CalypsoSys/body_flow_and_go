import 'package:flutter_test/flutter_test.dart';
import 'package:golog/features/feedback/domain/feedback_draft.dart';

void main() {
  group('FeedbackDraft', () {
    test('allows anonymous feedback and normalizes optional fields', () {
      const draft = FeedbackDraft(
        email: '   ',
        subject: '   ',
        message: '  The awake button is hard to find.  ',
      );

      expect(draft.validate(), isNull);

      final normalized = draft.normalized();
      expect(normalized.email, isEmpty);
      expect(normalized.subject, 'Body Flow & Go feedback');
      expect(normalized.message, 'The awake button is hard to find.');
    });

    test('trims a supplied email and subject without removing Unicode', () {
      const draft = FeedbackDraft(
        email: '  person@example.com  ',
        subject: '  Accessibility idea  ',
        message: '  Please preserve café and ❤.  ',
      );

      expect(draft.validate(), isNull);
      final normalized = draft.normalized();
      expect(normalized.email, 'person@example.com');
      expect(normalized.subject, 'Accessibility idea');
      expect(normalized.message, 'Please preserve café and ❤.');
    });

    test('requires a non-blank message', () {
      const draft = FeedbackDraft(
        email: '',
        subject: 'Question',
        message: ' \n\t ',
      );

      expect(draft.validate(), 'Message is required.');
    });

    test('rejects a malformed optional email', () {
      const draft = FeedbackDraft(
        email: 'not-an-email',
        subject: '',
        message: 'Hello',
      );

      expect(
        draft.validate(),
        'Enter a valid email address or leave it blank.',
      );
    });

    test('accepts values exactly at the configured length limits', () {
      final draft = FeedbackDraft(
        email: '',
        subject: _repeat('s', FeedbackDraft.fieldMaxLength),
        message: _repeat('m', FeedbackDraft.messageMaxLength),
      );

      expect(draft.validate(), isNull);
    });

    test('rejects a subject beyond the field limit', () {
      final draft = FeedbackDraft(
        email: '',
        subject: _repeat('s', FeedbackDraft.fieldMaxLength + 1),
        message: 'Hello',
      );

      expect(
        draft.validate(),
        'Email and subject must be 200 characters or fewer.',
      );
    });

    test('rejects a message beyond the message limit', () {
      final draft = FeedbackDraft(
        email: '',
        subject: '',
        message: _repeat('m', FeedbackDraft.messageMaxLength + 1),
      );

      expect(draft.validate(), 'Message must be 2000 characters or fewer.');
    });
  });
}

String _repeat(String value, int count) => List.filled(count, value).join();
