import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../data/placeholder_data.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(
          title: 'About Me',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(placeholderBio.trim(), style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/downloads'),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download Resume'),
              ),
            ],
          ),
        ),
        Section(
          title: 'Education',
          background: Theme.of(context).colorScheme.surfaceContainerLow,
          child: const _InfoCard(
            title: 'B.Sc. — Computer Science / AI & Cybersecurity focus',
            subtitle: 'Expected graduation 2027',
            body: 'Coursework emphasis on machine learning, applied cryptography, and network security, '
                'alongside independent research projects supervised by faculty.',
          ),
        ),
        Section(
          title: 'Research Philosophy',
          child: Text(
            'I believe the most useful research in AI and security is research that survives contact with '
            'real, messy systems — not just clean benchmark datasets. That means treating explainability, '
            'privacy, and reproducibility as design constraints from day one, not features bolted on later.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Section(
          title: 'Career Vision',
          background: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Text(placeholderResearchVision.trim(), style: Theme.of(context).textTheme.bodyLarge),
        ),
        Section(
          title: 'Technical Interests',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              Chip(label: Text('Federated Learning')),
              Chip(label: Text('Explainable AI (XAI)')),
              Chip(label: Text('Network Security')),
              Chip(label: Text('Applied Cryptography')),
              Chip(label: Text('Systems Programming')),
              Chip(label: Text('Natural Language Processing')),
            ],
          ),
        ),
        Section(
          title: 'Awards & Leadership',
          background: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A full list of awards and leadership experience is on the Awards & Achievements page.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => context.go('/awards'), child: const Text('View Awards & Achievements')),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle, required this.body});
  final String title;
  final String subtitle;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
