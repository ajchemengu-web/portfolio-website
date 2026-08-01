import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _visibilityOptions = ['public', 'view_only', 'private'];
const _categoryOptions = ['cv', 'paper', 'presentation', 'certificate', 'image', 'video', 'misc'];

final _adminFilesProvider = FutureProvider.autoDispose<List<DownloadFile>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/downloads/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => DownloadFile.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Media / Download Manager: upload, categorise, set visibility
/// (public / view-only / private), and delete every file used across the
/// site (CV, papers, certificates, presentations, images, video). This is
/// the single place files get uploaded to Supabase Storage — other
/// managers (Publications, Achievements) reference files created here by
/// id rather than uploading their own copies.
class MediaManagerPage extends ConsumerWidget {
  const MediaManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(_adminFilesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Media / Download Manager', addLabel: 'Upload File', onAdd: () => _openUpload(context, ref)),
        const SizedBox(height: 24),
        files.when(
          loading: () => const LoadingView(),
          error: (e, st) =>
              ErrorView(message: 'Could not load files: $e', onRetry: () => ref.invalidate(_adminFilesProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No files uploaded yet.', icon: Icons.upload_file_outlined);
            return Column(children: [for (final file in items) _AdminFileTile(file: file)]);
          },
        ),
      ],
    );
  }

  void _openUpload(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const _UploadDialog()).then((changed) {
      if (changed == true) ref.invalidate(_adminFilesProvider);
    });
  }
}

String _formatSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _AdminFileTile extends ConsumerWidget {
  const _AdminFileTile({required this.file});
  final DownloadFile file;

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed =
        await confirmDelete(context, title: 'Delete file?', message: '"${file.filename}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/downloads/admin/${file.id}');
    ref.invalidate(_adminFilesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(file.filename),
        subtitle: Text([
          if (file.category != null) file.category!,
          _formatSize(file.sizeBytes),
          '${file.downloadCount} downloads',
        ].where((s) => s.isNotEmpty).join(' · ')),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _VisibilityDropdown(file: file),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _VisibilityDropdown extends ConsumerWidget {
  const _VisibilityDropdown({required this.file});
  final DownloadFile file;

  Future<void> _updateVisibility(WidgetRef ref, String value) async {
    final client = ref.read(adminApiClientProvider);
    await client.put('/downloads/admin/${file.id}', body: {'visibility': value});
    ref.invalidate(_adminFilesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButton<String>(
      value: validDropdownValue(file.visibility, _visibilityOptions),
      underline: const SizedBox.shrink(),
      items: [for (final v in _visibilityOptions) DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ')))],
      onChanged: (value) {
        if (value != null) _updateVisibility(ref, value);
      },
    );
  }
}

class _UploadDialog extends ConsumerStatefulWidget {
  const _UploadDialog();

  @override
  ConsumerState<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends ConsumerState<_UploadDialog> {
  PlatformFile? _picked;
  final _descriptionController = TextEditingController();
  final _versionController = TextEditingController();
  String _category = _categoryOptions.first;
  String _visibility = 'private';
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _picked = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (_picked == null || _picked!.bytes == null) {
      setState(() => _error = 'Please choose a file first.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });

    final client = ref.read(adminApiClientProvider);
    try {
      await client.uploadMultipart(
        '/uploads',
        bytes: _picked!.bytes!,
        filename: _picked!.name,
        fields: {
          'category': _category,
          'visibility': _visibility,
          'description': _descriptionController.text.trim(),
          'version': _versionController.text.trim(),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on ApiUnreachableException {
      setState(() => _error = 'Could not reach the API.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload File'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_picked?.name ?? 'Choose file…'),
            ),
            if (_picked != null) ...[
              const SizedBox(height: 4),
              Text(_formatSize(_picked!.size), style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _versionController,
              decoration: const InputDecoration(labelText: 'Version (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in _categoryOptions) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: [for (final v in _visibilityOptions) DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' ')))],
              onChanged: (v) => setState(() => _visibility = v ?? _visibility),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _uploading ? null : _upload,
          child: _uploading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Upload'),
        ),
      ],
    );
  }
}
