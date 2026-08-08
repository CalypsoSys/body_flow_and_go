class FeedbackDraft {
  const FeedbackDraft({
    required this.email,
    required this.subject,
    required this.message,
  });

  static const fieldMaxLength = 200;
  static const messageMaxLength = 2000;

  final String email;
  final String subject;
  final String message;

  FeedbackDraft normalized() => FeedbackDraft(
    email: email.trim(),
    subject: subject.trim().isEmpty
        ? 'Body Flow & Go feedback'
        : subject.trim(),
    message: message.trim(),
  );

  String? validate() {
    final normalizedDraft = normalized();
    if (normalizedDraft.message.isEmpty) {
      return 'Message is required.';
    }
    if (normalizedDraft.email.isNotEmpty &&
        !_looksLikeEmail(normalizedDraft.email)) {
      return 'Enter a valid email address or leave it blank.';
    }
    if (normalizedDraft.email.length > fieldMaxLength ||
        normalizedDraft.subject.length > fieldMaxLength) {
      return 'Email and subject must be $fieldMaxLength characters or fewer.';
    }
    if (normalizedDraft.message.length > messageMaxLength) {
      return 'Message must be $messageMaxLength characters or fewer.';
    }
    return null;
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}
