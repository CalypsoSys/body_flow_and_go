import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/feedback_draft.dart';
import '../domain/feedback_repository.dart';

abstract interface class FeedbackTransport {
  Future<int> postJson(
    Uri endpoint,
    Map<String, Object> payload, {
    required Map<String, String> headers,
  });
}

class IoFeedbackTransport implements FeedbackTransport {
  const IoFeedbackTransport({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;

  @override
  Future<int> postJson(
    Uri endpoint,
    Map<String, Object> payload, {
    required Map<String, String> headers,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      return response.statusCode;
    } on TimeoutException {
      throw const FeedbackSubmissionException();
    } on IOException {
      throw const FeedbackSubmissionException();
    } finally {
      client.close(force: true);
    }
  }
}

class HttpFeedbackRepository implements FeedbackRepository {
  HttpFeedbackRepository({
    required Uri endpoint,
    this.transport = const IoFeedbackTransport(),
    this.clientName = 'body-flow-and-go-android',
    this.appVersion = '1.0.0+1',
  }) : endpoint = _validateEndpoint(endpoint);

  factory HttpFeedbackRepository.production() {
    const endpointValue = String.fromEnvironment(
      'BODY_FLOW_AND_GO_FEEDBACK_URL',
      defaultValue: 'https://hashimojoe.com/api/feedback',
    );
    const version = String.fromEnvironment(
      'BODY_FLOW_AND_GO_APP_VERSION',
      defaultValue: '1.0.0+1',
    );
    return HttpFeedbackRepository(
      endpoint: Uri.parse(endpointValue),
      clientName: 'body-flow-and-go-${Platform.operatingSystem}',
      appVersion: version,
    );
  }

  final Uri endpoint;
  final FeedbackTransport transport;
  final String clientName;
  final String appVersion;

  @override
  Future<void> submit(FeedbackDraft draft) async {
    if (draft.validate() case final error?) {
      throw ArgumentError.value(draft, 'draft', error);
    }
    final normalized = draft.normalized();
    final statusCode = await transport.postJson(
      endpoint,
      <String, Object>{
        // The shared feedback backend currently requires this field. Keep it
        // pseudonymous so Body Flow & Go never requires a user's real name.
        'name': 'Anonymous Body Flow & Go user',
        'email': normalized.email,
        'subject': normalized.subject,
        'message': normalized.message,
        'source': clientName,
      },
      headers: <String, String>{
        'X-AIP-Client': clientName,
        'X-AIP-App-Version': appVersion,
      },
    );
    if (statusCode < 200 || statusCode >= 300) {
      throw const FeedbackSubmissionException();
    }
  }

  static Uri _validateEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'The feedback endpoint must be an absolute HTTPS URL.',
      );
    }
    return endpoint;
  }
}
