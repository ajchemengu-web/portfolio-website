import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/widgets/common.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

String _formatSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    return Section(
      title: 'Downloads',
      subtitle: 'CV, research papers, presentations, technical reports, and certificates.',
      child: downloads.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load downloads: $e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No downloadable files yet.');
          return Column(children: [for (final file in items) _DownloadTile(file: file)]);
        },
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.file});
  final DownloadFile file;

  Future<void> _download(WidgetRef ref, BuildContext context) async {
    final client = ref.read(publicApiClientProvider);
    try {
      final result = await client.get('/downloads/${file.id}/download');
      final url = (result as Map)['url'] as String?;
      if (url != null) {
        await launcher.launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not download: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewOnly = file.visibility == 'view_only';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(file.filename, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text([
          if (file.description != null) file.description!,
          if (file.version != null) file.version!,
          _formatSize(file.sizeBytes),
        ].where((s) => s.isNotEmpty).join(' · ')),
        trailing: viewOnly
            ? const Chip(label: Text('View only'))
            : IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Download',
                onPressed: () => _download(ref, context),
              ),
      ),
    );
  }
}
