import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/widgets/common.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';
import '../admin/auth/auth_controller.dart';

class PublicationsPage extends ConsumerWidget {
  const PublicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publications = ref.watch(publicationsListProvider);
    return Section(
      title: 'Publications',
      subtitle: 'Research papers, technical reports, conference papers, white papers, and preprints.',
      child: publications.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load publications: $e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No publications yet.');
          return Column(
            children: [for (final pub in items) _PublicationTile(publication: pub)],
          );
        },
      ),
    );
  }
}

class _PublicationTile extends ConsumerWidget {
  const _PublicationTile({required this.publication});
  final Publication publication;

  String _typeLabel(String type) => type.replaceAll('_', ' ');

  Future<void> _download(WidgetRef ref) async {
    final client = ref.read(publicApiClientProvider);
    // The API mints a fresh (possibly short-lived, signed) URL on demand
    // rather than exposing a permanent storage link — see the backend's
    // /publications/<slug>/download endpoint.
    final result = await client.get('/publications/${publication.slug}/download');
    final url = (result as Map)['url'] as String?;
    if (url != null) {
      await launcher.launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDownload = publication.file != null && publication.file!.visibility != 'private';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, children: [
              Chip(label: Text(_typeLabel(publication.publicationType))),
              if (publication.publicationDate != null)
                Chip(label: Text('${publication.publicationDate!.year}')),
            ]),
            const SizedBox(height: 12),
            Text(publication.title, style: Theme.of(context).textTheme.titleLarge),
            if (publication.authors.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(publication.authors.join(', '), style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (publication.abstractText != null) ...[
              const SizedBox(height: 12),
              Text(publication.abstractText!, style: Theme.of(context).textTheme.bodyLarge),
            ],
            if (publication.citation != null) ...[
              const SizedBox(height: 12),
              Text(publication.citation!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                if (canDownload)
                  OutlinedButton.icon(
                    onPressed: () => _download(ref),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download PDF'),
                  ),
                if (publication.doi != null)
                  TextButton(
                    onPressed: () => launcher.launchUrl(Uri.parse('https://doi.org/${publication.doi}'),
                        webOnlyWindowName: '_blank'),
                    child: Text('DOI: ${publication.doi}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
