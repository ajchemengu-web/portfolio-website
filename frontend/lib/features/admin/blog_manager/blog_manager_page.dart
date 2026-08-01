import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

class BlogManagerPage extends ConsumerWidget {
  const BlogManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(_adminBlogPostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Blog Manager', addLabel: 'New Post', onAdd: () => _openEditor(context, ref)),
        const SizedBox(height: 24),
        posts.when(
          loading: () => const LoadingView(),
          error: (e, st) =>
              ErrorView(message: 'Could not load blog posts: $e', onRetry: () => ref.invalidate(_adminBlogPostsProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No blog posts yet — write the first one.');
            return Column(children: [for (final post in items) _AdminBlogTile(post: post)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [BlogPost? existing]) {
    showDialog(context: context, builder: (_) => _BlogEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(_adminBlogPostsProvider);
    });
  }
}

final _adminBlogPostsProvider = FutureProvider.autoDispose<List<BlogPost>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/blog/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => BlogPost.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class _AdminBlogTile extends ConsumerWidget {
  const _AdminBlogTile({required this.post});
  final BlogPost post;

  Future<void> _publish(WidgetRef ref) async {
    final client = ref.read(adminApiClientProvider);
    await client.post('/blog/admin/${post.id}/publish');
    ref.invalidate(_adminBlogPostsProvider);
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed =
        await confirmDelete(context, title: 'Delete post?', message: '"${post.title}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/blog/admin/${post.id}');
    ref.invalidate(_adminBlogPostsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(post.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, children: [
            Chip(label: Text(post.status)),
            if (post.category != null) Chip(label: Text(post.category!)),
          ]),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => showDialog(context: context, builder: (_) => _BlogEditorDialog(existing: post))
                  .then((changed) {
                if (changed == true) ref.invalidate(_adminBlogPostsProvider);
              }),
            ),
            if (post.status != 'published')
              IconButton(icon: const Icon(Icons.publish_outlined), tooltip: 'Publish', onPressed: () => _publish(ref)),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _BlogEditorDialog extends ConsumerStatefulWidget {
  const _BlogEditorDialog({this.existing});
  final BlogPost? existing;

  @override
  ConsumerState<_BlogEditorDialog> createState() => _BlogEditorDialogState();
}

class _BlogEditorDialogState extends ConsumerState<_BlogEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _excerpt;
  late final TextEditingController _content;
  late final TextEditingController _category;
  late final TextEditingController _tags;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _excerpt = TextEditingController(text: e?.excerpt ?? '');
    _content = TextEditingController(text: e?.contentMarkdown ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _tags = TextEditingController(text: e?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _excerpt.dispose();
    _content.dispose();
    _category.dispose();
    _tags.dispose();
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
      'excerpt': _excerpt.text.trim(),
      'content_markdown': _content.text,
      'category': _category.text.trim(),
      'tags': parseCommaList(_tags.text),
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/blog/admin', body: payload);
      } else {
        await client.put('/blog/admin/${widget.existing!.id}', body: payload);
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
      title: widget.existing == null ? 'New Blog Post' : 'Edit Blog Post',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      onSave: _save,
      maxWidth: 720,
      fields: [
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _excerpt, decoration: const InputDecoration(labelText: 'Excerpt'), maxLines: 2),
        const SizedBox(height: 12),
        TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
        const SizedBox(height: 12),
        TextFormField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags (comma-separated)')),
        const SizedBox(height: 12),
        TextFormField(
          controller: _content,
          decoration: const InputDecoration(
            labelText: 'Content (Markdown)',
            alignLabelWithHint: true,
          ),
          maxLines: 12,
        ),
        const SizedBox(height: 8),
        Text(
          'New posts save as a draft. Use "Publish" from the list once you\'re happy with it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
