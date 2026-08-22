import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

class TermsOfUseScreen extends ConsumerWidget {
  const TermsOfUseScreen({super.key, this.requireAcceptance = false});

  final bool requireAcceptance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _TermsCard(
              title: 'Personal tracking only',
              body:
                  'Body Flow & Go is provided for personal recording and '
                  'review of urination and bowel movement events. It is not '
                  'a medical device and is not intended to replace care from '
                  'a qualified healthcare professional.',
            ),
            const SizedBox(height: 12),
            const _TermsCard(
              title: 'No medical advice',
              body:
                  'The app does not provide medical advice, diagnosis, '
                  'treatment, prevention, or recommendations for a disease or '
                  'condition. Seek professional care for symptoms or health '
                  'concerns. For emergencies, contact local emergency '
                  'services.',
            ),
            const SizedBox(height: 12),
            const _TermsCard(
              title: 'Your responsibility',
              body:
                  'You are responsible for deciding whether and how to use '
                  'the app and for seeking appropriate professional care. '
                  'Do not rely on the app for urgent decisions.',
            ),
            const SizedBox(height: 12),
            const _TermsCard(
              title: 'Accuracy and availability',
              body:
                  'We do not guarantee that records, calculations, exports, '
                  'notifications, or app availability will always be '
                  'complete, accurate, uninterrupted, or error-free. Keep '
                  'your device and operating system protected and maintain '
                  'your own backups of any exported files.',
            ),
            const SizedBox(height: 12),
            const _TermsCard(
              title: 'Use at your own risk',
              body:
                  'To the extent permitted by law, you use Body Flow & Go at '
                  'your own risk. These terms do not limit rights or '
                  'protections that cannot legally be limited.',
            ),
            if (requireAcceptance) ...[
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('accept_terms_button'),
                onPressed: () async {
                  final settings = ref.read(settingsControllerProvider).value;
                  if (settings == null) return;
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .saveSettings(settings.copyWith(termsAccepted: true));
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('I understand and continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
