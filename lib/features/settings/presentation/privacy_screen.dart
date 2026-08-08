import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & purpose')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _PrivacyCard(
              icon: Icons.shield_outlined,
              title: 'Your records stay on this device',
              body:
                  'Body Flow & Go stores events in the app’s private local '
                  'database. It does not require an account and never '
                  'automatically sends health records to any server.',
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              icon: Icons.feedback_outlined,
              title: 'Optional feedback uses the internet',
              body:
                  'Nothing is sent unless you open the feedback form, enter '
                  'information, confirm the disclosure, and tap Send. The '
                  'reply email, subject, and message you enter are sent over '
                  'HTTPS to Calypso Systems and may be routed through Slack. '
                  'Basic network metadata may be processed to secure the '
                  'service. No stored event, note, trend, or export data is '
                  'attached. Do not include health information. Submitted '
                  'feedback may be retained as needed to review and respond '
                  'to it and protect the service. It is not sold.',
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              icon: Icons.visibility_off_outlined,
              title: 'No ads or analytics',
              body:
                  'Body Flow & Go contains no advertising or analytics SDKs. '
                  'It does not profile your activity.',
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              icon: Icons.ios_share_outlined,
              title: 'Exports are user controlled',
              body:
                  'CSV and JSON files are created only when you request an '
                  'export. After you choose a destination in the system share '
                  'sheet, that copy is outside Body Flow & Go’s private '
                  'storage and is governed by the destination you selected.',
            ),
            const SizedBox(height: 12),
            _PrivacyCard(
              icon: Icons.medical_information_outlined,
              title: 'Personal tracking, not diagnosis',
              body:
                  'Body Flow & Go is a personal tracking tool. It is not a '
                  'medical device, does not provide a diagnosis, and is not '
                  'a substitute for professional medical advice. Contact a '
                  'qualified clinician about symptoms or health concerns.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
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
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    );
  }
}
