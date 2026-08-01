import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _publicationTypes = ['paper', 'technical_report', 'conference', 'white_paper', 'preprint'];

final _adminPublicationsProvider = FutureProvider.autoDispose<List<Publication>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/publications/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => Publication.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Files available to attach to a publication — populated from the Media
/// Manager. A publication doesn't upload its own file; it references one
/// already uploaded, keeping "where files come from" in a single place.
final _availableFilesProvider = FutureProvider.autoDispose<List<DownloadFile>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/downloads/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => DownloadFile.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class PublicationManagerPage extends ConsumerWidget {
  const PublicationManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publications = ref.watch(_adminPublicationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(
          title: 'Publication Manager',
          addLabel: 'New Publication',
          onAdd: () => _openEditor(context, ref),
        ),
        const SizedBox(height: 24),
        publications.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            message: 'Could not load publications: $e',
            onRetry: () => ref.invalidate(_adminPublicationsProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No publications yet — add the first one.');
            return Column(children: [for (final pub in items) _AdminPublicationTile(publication: pub)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [Publication? existing]) {
    showDialog(context: context, builder: (_) => _PublicationEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(_adminPublicationsProvider);
    });
  }
}

class _AdminPublicationTile extends ConsumerWidget {
  const _AdminPublicationTile({required this.publication});
  final Publication publication;

  Future<void> _publish(WidgetRef ref) async {
    final client = ref.read(adminApiClientProvider);
    await client.post('/publications/admin/${publication.id}/publish');
    ref.invalidate(_adminPublicationsProvider);
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed = await confirmDelete(context,
        title: 'Delete publication?', message: '"${publication.title}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/publications/admin/${publication.id}');
    ref.invalidate(_adminPublicationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(publication.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(publication.publicationType.replaceAll('_', ' '))),
              if (publication.file != null) const Chip(label: Text('File attached')),
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _PublicationEditorDialog(existing: publication),
              ).then((changed) {
                if (changed == true) ref.invalidate(_adminPublicationsProvider);
              }),
            ),
            IconButton(icon: const Icon(Icons.publish_outlined), tooltip: 'Publish', onPressed: () => _publish(ref)),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _PublicationEditorDialog extends ConsumerStatefulWidget {
  const _PublicationEditorDialog({this.existing});
  final Publication? existing;

  @override
  ConsumerState<_PublicationEditorDialog> createState() => _PublicationEditorDialogState();
}

class _PublicationEditorDialogState extends ConsumerState<_PublicationEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _abstract;
  late final TextEditingController _citation;
  late final TextEditingController _authors;
  late final TextEditingController _doi;
  late String _type;
  String? _fileAssetId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _abstract = TextEditingController(text: e?.abstractText ?? '');
    _citation = TextEditingController(text: e?.citation ?? '');
    _authors = TextEditingController(text: e?.authors.join(', ') ?? '');
    _doi = TextEditingController(text: e?.doi ?? '');
    _type = validDropdownValue(e?.publicationType, _publicationTypes);
    _fileAssetId = e?.file?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _abstract.dispose();
    _citation.dispose();
    _authors.dispose();
    _doi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = {
      'title': _title.text.trim(),
      'publication_type': _type,
      'abstract': _abstract.text.trim(),
      'citation': _citation.text.trim(),
      'authors': parseCommaList(_authors.text),
      'doi': _doi.text.trim(),
      if (_fileAssetId != null) 'file_asset_id': _fileAssetId,
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/publications/admin', body: payload);
      } else {
        await client.put('/publications/admin/${widget.existing!.id}', body: payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on ApiUnreachableException {
      setState(() => _error = 'Could not reach the API.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableFiles = ref.watch(_availableFilesProvider);

    return EditorDialogShell(
      title: widget.existing == null ? 'New Publication' : 'Edit Publication',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      onSave: _save,
      fields: [
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final t in _publicationTypes) DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _abstract, decoration: const InputDecoration(labelText: 'Abstract'), maxLines: 3),
        const SizedBox(height: 12),
        TextFormField(controller: _citation, decoration: const InputDecoration(labelText: 'Citation'), maxLines: 2),
        const SizedBox(height: 12),
        TextFormField(
          controller: _authors,
          decoration: const InputDecoration(labelText: 'Authors (comma-separated)'),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _doi, decoration: const InputDecoration(labelText: 'DOI (optional)')),
        const SizedBox(height: 16),
        availableFiles.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, st) => const Text('Could not load uploaded files.'),
          data: (files) => DropdownButtonFormField<String?>(
            value: _fileAssetId,
            decoration: const InputDecoration(labelText: 'Attached file (upload via Media Manager first)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final f in files) DropdownMenuItem(value: f.id, child: Text(f.filename)),
            ],
            onChanged: (v) => setState(() => _fileAssetId = v),
          ),
        ),
      ],
    );
  }
}
