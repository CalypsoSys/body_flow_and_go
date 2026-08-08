import 'package:flutter_test/flutter_test.dart';
import 'package:golog/features/feedback/data/http_feedback_repository.dart';
import 'package:golog/features/feedback/domain/feedback_draft.dart';
import 'package:golog/features/feedback/domain/feedback_repository.dart';

void main() {
  group('HttpFeedbackRepository', () {
    test('requires an absolute HTTPS endpoint', () {
      expect(
        () => HttpFeedbackRepository(
          endpoint: Uri.parse('http://feedback.example.com/api/feedback'),
        ),
        throwsArgumentError,
      );
      expect(
        () => HttpFeedbackRepository(endpoint: Uri.parse('/api/feedback')),
        throwsArgumentError,
      );
    });

    test(
      'posts normalized anonymous payload and public client headers',
      () async {
        final transport = _RecordingFeedbackTransport(statusCode: 204);
        final endpoint = Uri.parse('https://feedback.example.com/api/feedback');
        final repository = HttpFeedbackRepository(
          endpoint: endpoint,
          transport: transport,
          clientName: 'body-flow-and-go-test',
          appVersion: '1.2.3+45',
        );

        await repository.submit(
          const FeedbackDraft(
            email: '   ',
            subject: '   ',
            message: '  A concise anonymous message.  ',
          ),
        );

        expect(transport.calls, 1);
        expect(transport.endpoint, endpoint);
        expect(transport.payload, <String, Object>{
          'name': 'Anonymous Body Flow & Go user',
          'email': '',
          'subject': 'Body Flow & Go feedback',
          'message': 'A concise anonymous message.',
          'source': 'body-flow-and-go-test',
        });
        expect(transport.headers, <String, String>{
          'X-AIP-Client': 'body-flow-and-go-test',
          'X-AIP-App-Version': '1.2.3+45',
        });
      },
    );

    test('includes a normalized optional reply email', () async {
      final transport = _RecordingFeedbackTransport(statusCode: 200);
      final repository = HttpFeedbackRepository(
        endpoint: Uri.parse('https://feedback.example.com/feedback'),
        transport: transport,
      );

      await repository.submit(
        const FeedbackDraft(
          email: '  person@example.com ',
          subject: '  Reply requested ',
          message: '  Please contact me. ',
        ),
      );

      expect(transport.payload?['email'], 'person@example.com');
      expect(transport.payload?['subject'], 'Reply requested');
      expect(transport.payload?['message'], 'Please contact me.');
    });

    test('maps every non-2xx status to a submission exception', () async {
      for (final statusCode in <int>[199, 300, 400, 503]) {
        final repository = HttpFeedbackRepository(
          endpoint: Uri.parse('https://feedback.example.com/feedback'),
          transport: _RecordingFeedbackTransport(statusCode: statusCode),
        );

        await expectLater(
          repository.submit(
            const FeedbackDraft(email: '', subject: '', message: 'Hello'),
          ),
          throwsA(isA<FeedbackSubmissionException>()),
          reason: 'status $statusCode must fail',
        );
      }
    });

    test('rejects an invalid draft before using the transport', () async {
      final transport = _RecordingFeedbackTransport(statusCode: 200);
      final repository = HttpFeedbackRepository(
        endpoint: Uri.parse('https://feedback.example.com/feedback'),
        transport: transport,
      );

      await expectLater(
        repository.submit(
          const FeedbackDraft(email: 'invalid', subject: '', message: 'Hello'),
        ),
        throwsArgumentError,
      );
      expect(transport.calls, 0);
    });
  });
}

class _RecordingFeedbackTransport implements FeedbackTransport {
  _RecordingFeedbackTransport({required this.statusCode});

  final int statusCode;
  int calls = 0;
  Uri? endpoint;
  Map<String, Object>? payload;
  Map<String, String>? headers;

  @override
  Future<int> postJson(
    Uri endpoint,
    Map<String, Object> payload, {
    required Map<String, String> headers,
  }) async {
    calls++;
    this.endpoint = endpoint;
    this.payload = Map<String, Object>.from(payload);
    this.headers = Map<String, String>.from(headers);
    return statusCode;
  }
}
