import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/feedback_draft.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _acknowledged = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send feedback')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Feedback is optional. The reply email, subject, and '
                        'message you enter are sent over the internet to Calypso '
                        'Systems and may be routed through Slack. Basic network metadata '
                        'may be processed for security. No stored event, note, '
                        'trend, or export data is attached. Do not include '
                        'health information, medical details, or emergency '
                        'requests in your message. Feedback is not monitored '
                        'for emergencies and is not medical support.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('feedback_email_field'),
              controller: _emailController,
              maxLength: FeedbackDraft.fieldMaxLength,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Reply email',
                hintText: 'Optional — leave blank to omit contact details',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('feedback_subject_field'),
              controller: _subjectController,
              maxLength: FeedbackDraft.fieldMaxLength,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('feedback_message_field'),
              controller: _messageController,
              minLines: 4,
              maxLines: 8,
              maxLength: FeedbackDraft.messageMaxLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'What should we know?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              key: const Key('feedback_acknowledgement'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acknowledged,
              onChanged: _submitting
                  ? null
                  : (value) {
                      setState(() {
                        _acknowledged = value ?? false;
                        _errorMessage = null;
                      });
                    },
              title: const Text('I understand and want to send this feedback.'),
            ),
            if (_errorMessage case final error?) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const Key('feedback_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('send_feedback_button'),
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Sending...' : 'Send feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final draft = FeedbackDraft(
      email: _emailController.text,
      subject: _subjectController.text,
      message: _messageController.text,
    );
    final validationError = draft.validate();
    if (!_acknowledged || validationError != null) {
      setState(() {
        _errorMessage = !_acknowledged
            ? 'Confirm that you understand how feedback is sent.'
            : validationError;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(feedbackRepositoryProvider).submit(draft);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks. Your feedback was sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage =
            'Feedback could not be sent. Check your connection and try again.';
      });
    }
  }
}
