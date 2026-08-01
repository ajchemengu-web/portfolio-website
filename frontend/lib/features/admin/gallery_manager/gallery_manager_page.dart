import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _galleryCategories = ['research', 'conference', 'project', 'laboratory'];

final _adminGalleryProvider = FutureProvider.autoDispose<List<GalleryItem>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/gallery/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => GalleryItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class GalleryManagerPage extends ConsumerWidget {
  const GalleryManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(_adminGalleryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Gallery Manager', addLabel: 'New Photo', onAdd: () => _openEditor(context, ref)),
        const SizedBox(height: 8),
        Text(
          'Upload the image file itself via the Media Manager first, then paste its public URL here.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        gallery.when(
          loading: () => const LoadingView(),
          error: (e, st) =>
              ErrorView(message: 'Could not load the gallery: $e', onRetry: () => ref.invalidate(_adminGalleryProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No photos yet — add the first one.');
            return Column(children: [for (final item in items) _AdminGalleryTile(item: item)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [GalleryItem? existing]) {
    showDialog(context: context, builder: (_) => _GalleryEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(_adminGalleryProvider);
    });
  }
}

class _AdminGalleryTile extends ConsumerWidget {
  const _AdminGalleryTile({required this.item});
  final GalleryItem item;

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed = await confirmDelete(context,
        title: 'Delete photo?', message: '"${item.title ?? item.imageUrl}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/gallery/admin/${item.id}');
    ref.invalidate(_adminGalleryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            item.imageUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined),
          ),
        ),
        title: Text(item.title ?? '(untitled)'),
        subtitle: Text(item.category),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  showDialog(context: context, builder: (_) => _GalleryEditorDialog(existing: item)).then((changed) {
                if (changed == true) ref.invalidate(_adminGalleryProvider);
              }),
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _GalleryEditorDialog extends ConsumerStatefulWidget {
  const _GalleryEditorDialog({this.existing});
  final GalleryItem? existing;

  @override
  ConsumerState<_GalleryEditorDialog> createState() => _GalleryEditorDialogState();
}

class _GalleryEditorDialogState extends ConsumerState<_GalleryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late String _category;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _category = validDropdownValue(e?.category, _galleryCategories);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _imageUrl.dispose();
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
      'description': _description.text.trim(),
      'image_url': _imageUrl.text.trim(),
      'category': _category,
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/gallery/admin', body: payload);
      } else {
        await client.put('/gallery/admin/${widget.existing!.id}', body: payload);
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
    return EditorDialogShell(
      title: widget.existing == null ? 'New Gallery Photo' : 'Edit Gallery Photo',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      onSave: _save,
      maxHeight: 520,
      fields: [
        TextFormField(
          controller: _imageUrl,
          decoration: const InputDecoration(labelText: 'Image URL'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Image URL is required.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title (optional)')),
        const SizedBox(height: 12),
        TextFormField(
            controller: _description, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in _galleryCategories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
      ],
    );
  }
}
