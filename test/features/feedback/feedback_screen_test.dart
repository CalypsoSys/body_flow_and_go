import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golog/app/providers.dart';
import 'package:golog/features/feedback/domain/feedback_draft.dart';
import 'package:golog/features/feedback/domain/feedback_repository.dart';
import 'package:golog/features/feedback/presentation/feedback_screen.dart';

void main() {
  testWidgets('requires acknowledgement before submitting', (tester) async {
    final repository = _RecordingFeedbackRepository();
    await _openFeedbackScreen(tester, repository);
    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'The buttons could use clearer labels.',
    );

    await _tapVisible(tester, find.byKey(const Key('send_feedback_button')));

    expect(
      find.text('Confirm that you understand how feedback is sent.'),
      findsOneWidget,
    );
    expect(repository.submissions, isEmpty);

    await _tapVisible(
      tester,
      find.byKey(const Key('feedback_acknowledgement')),
    );

    expect(find.byKey(const Key('feedback_error')), findsNothing);
  });

  testWidgets('submits anonymous feedback and shows success confirmation', (
    tester,
  ) async {
    final pendingSubmission = Completer<void>();
    final repository = _RecordingFeedbackRepository(
      pendingSubmission: pendingSubmission,
    );
    await _openFeedbackScreen(tester, repository);
    await tester.enterText(
      find.byKey(const Key('feedback_subject_field')),
      'Navigation idea',
    );
    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'Please make History easier to reach.',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('feedback_acknowledgement')),
    );

    await _tapVisible(tester, find.byKey(const Key('send_feedback_button')));

    expect(repository.submissions, hasLength(1));
    expect(repository.submissions.single.email, isEmpty);
    expect(repository.submissions.single.subject, 'Navigation idea');
    expect(
      repository.submissions.single.message,
      'Please make History easier to reach.',
    );
    expect(find.text('Sending...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('send_feedback_button')))
          .onPressed,
      isNull,
    );

    pendingSubmission.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feedback_test_host')), findsOneWidget);
    expect(find.text('Thanks. Your feedback was sent.'), findsOneWidget);
  });

  testWidgets('keeps the form open and reports repository errors', (
    tester,
  ) async {
    final repository = _RecordingFeedbackRepository(
      error: const FeedbackSubmissionException(),
    );
    await _openFeedbackScreen(tester, repository);
    await tester.enterText(
      find.byKey(const Key('feedback_email_field')),
      'person@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('feedback_message_field')),
      'Sending fails in this test.',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('feedback_acknowledgement')),
    );

    await _tapVisible(tester, find.byKey(const Key('send_feedback_button')));
    await tester.pumpAndSettle();

    expect(repository.submissions, hasLength(1));
    expect(find.text('Send feedback'), findsWidgets);
    expect(
      find.text(
        'Feedback could not be sent. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('send_feedback_button')))
          .onPressed,
      isNotNull,
    );
  });
}

Future<void> _openFeedbackScreen(
  WidgetTester tester,
  FeedbackRepository repository,
) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [feedbackRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('feedback_test_host'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FeedbackScreen(),
                    ),
                  );
                },
                child: const Text('Open feedback'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('feedback_test_host')));
  await tester.pumpAndSettle();
  expect(find.byType(FeedbackScreen), findsOneWidget);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

class _RecordingFeedbackRepository implements FeedbackRepository {
  _RecordingFeedbackRepository({this.pendingSubmission, this.error});

  final Completer<void>? pendingSubmission;
  final Object? error;
  final List<FeedbackDraft> submissions = [];

  @override
  Future<void> submit(FeedbackDraft draft) {
    submissions.add(draft);
    if (error case final submissionError?) {
      return Future<void>.error(submissionError);
    }
    return pendingSubmission?.future ?? Future<void>.value();
  }
}
