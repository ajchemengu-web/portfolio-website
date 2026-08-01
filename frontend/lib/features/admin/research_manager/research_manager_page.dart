import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _statusOptions = ['planning', 'active', 'completed', 'published'];

final _adminResearchListProvider = FutureProvider.autoDispose<List<ResearchProject>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/research/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => ResearchProject.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Full CRUD module for managing Research projects — create, edit,
/// publish/archive, and delete — matching the PRD's "Research Manager"
/// dashboard module. This was the reference pattern for every other
/// manager in features/admin/ (Publication, Project, Blog, Skills,
/// Timeline, Achievement, Gallery, Media) — they all follow the same
/// list + EditorDialogShell + confirmDelete structure (see
/// features/admin/widgets/admin_common.dart).
class ResearchManagerPage extends ConsumerWidget {
  const ResearchManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final research = ref.watch(_adminResearchListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Research Manager', style: Theme.of(context).textTheme.headlineSmall),
            FilledButton.icon(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New Research Project'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        research.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            message: 'Could not load research projects: $e',
            onRetry: () => ref.invalidate(_adminResearchListProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No research projects yet — create the first one.');
            return Column(
              children: [for (final project in items) _AdminResearchTile(project: project)],
            );
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [ResearchProject? existing]) {
    showDialog(
      context: context,
      builder: (_) => _ResearchEditorDialog(existing: existing),
    ).then((changed) {
      if (changed == true) ref.invalidate(_adminResearchListProvider);
    });
  }
}

class _AdminResearchTile extends ConsumerWidget {
  const _AdminResearchTile({required this.project});
  final ResearchProject project;

  Future<void> _publish(WidgetRef ref, BuildContext context) async {
    final client = ref.read(adminApiClientProvider);
    await client.post('/research/admin/${project.id}/publish');
    ref.invalidate(_adminResearchListProvider);
  }

  Future<void> _archive(WidgetRef ref, BuildContext context) async {
    final client = ref.read(adminApiClientProvider);
    await client.post('/research/admin/${project.id}/archive');
    ref.invalidate(_adminResearchListProvider);
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete research project?'),
        content: Text('"${project.title}" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/research/admin/${project.id}');
    ref.invalidate(_adminResearchListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(project.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: project.status),
              if (project.isDraft) const Chip(label: Text('Draft')) else const Chip(label: Text('Published')),
              Text('${project.progressPercentage}% complete'),
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
                builder: (_) => _ResearchEditorDialog(existing: project),
              ).then((changed) {
                if (changed == true) ref.invalidate(_adminResearchListProvider);
              }),
            ),
            if (project.isDraft)
              IconButton(
                icon: const Icon(Icons.publish_outlined),
                tooltip: 'Publish',
                onPressed: () => _publish(ref, context),
              )
            else
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: 'Unpublish / Archive',
                onPressed: () => _archive(ref, context),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _delete(ref, context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchEditorDialog extends ConsumerStatefulWidget {
  const _ResearchEditorDialog({this.existing});
  final ResearchProject? existing;

  @override
  ConsumerState<_ResearchEditorDialog> createState() => _ResearchEditorDialogState();
}

class _ResearchEditorDialogState extends ConsumerState<_ResearchEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _abstract;
  late final TextEditingController _researchQuestion;
  late final TextEditingController _methodology;
  late final TextEditingController _results;
  late String _status;
  late double _progress;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _category = TextEditingController(text: e?.category ?? '');
    _abstract = TextEditingController(text: e?.abstractText ?? '');
    _researchQuestion = TextEditingController(text: e?.researchQuestion ?? '');
    _methodology = TextEditingController(text: e?.methodology ?? '');
    _results = TextEditingController(text: e?.results ?? '');
    _status = validDropdownValue(e?.status, _statusOptions);
    _progress = (e?.progressPercentage ?? 0).toDouble();
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _abstract.dispose();
    _researchQuestion.dispose();
    _methodology.dispose();
    _results.dispose();
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
      'category': _category.text.trim(),
      'abstract': _abstract.text.trim(),
      'research_question': _researchQuestion.text.trim(),
      'methodology': _methodology.text.trim(),
      'results': _results.text.trim(),
      'status': _status,
      'progress_percentage': _progress.round(),
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/research/admin', body: payload);
      } else {
        await client.put('/research/admin/${widget.existing!.id}', body: payload);
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.existing == null ? 'New Research Project' : 'Edit Research Project',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _abstract,
                          decoration: const InputDecoration(labelText: 'Abstract'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _researchQuestion,
                          decoration: const InputDecoration(labelText: 'Research Question'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _methodology,
                          decoration: const InputDecoration(labelText: 'Methodology'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _results,
                          decoration: const InputDecoration(labelText: 'Results'),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: [for (final s in _statusOptions) DropdownMenuItem(value: s, child: Text(s))],
                          onChanged: (v) => setState(() => _status = v ?? _status),
                        ),
                        const SizedBox(height: 16),
                        Text('Progress: ${_progress.round()}%'),
                        Slider(
                          value: _progress,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${_progress.round()}%',
                          onChanged: (v) => setState(() => _progress = v),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
