import 'feedback_draft.dart';

abstract interface class FeedbackRepository {
  Future<void> submit(FeedbackDraft draft);
}

class FeedbackSubmissionException implements Exception {
  const FeedbackSubmissionException();

  @override
  String toString() => 'FeedbackSubmissionException';
}
