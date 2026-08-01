import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _projectStatuses = ['planning', 'active', 'completed', 'published'];

final _adminProjectsProvider = FutureProvider.autoDispose<List<SoftwareProject>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/projects/admin/all', query: {'page_size': 100});
  return (Map<String, dynamic>.from(result as Map)['items'] as List)
      .map((e) => SoftwareProject.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class ProjectManagerPage extends ConsumerWidget {
  const ProjectManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(_adminProjectsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Project Manager', addLabel: 'New Project', onAdd: () => _openEditor(context, ref)),
        const SizedBox(height: 24),
        projects.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            message: 'Could not load projects: $e',
            onRetry: () => ref.invalidate(_adminProjectsProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No projects yet — add the first one.');
            return Column(children: [for (final p in items) _AdminProjectTile(project: p)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [SoftwareProject? existing]) {
    showDialog(context: context, builder: (_) => _ProjectEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(_adminProjectsProvider);
    });
  }
}

class _AdminProjectTile extends ConsumerWidget {
  const _AdminProjectTile({required this.project});
  final SoftwareProject project;

  Future<void> _publish(WidgetRef ref) async {
    final client = ref.read(adminApiClientProvider);
    await client.post('/projects/admin/${project.id}/publish');
    ref.invalidate(_adminProjectsProvider);
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed =
        await confirmDelete(context, title: 'Delete project?', message: '"${project.title}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/projects/admin/${project.id}');
    ref.invalidate(_adminProjectsProvider);
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
          child: Wrap(spacing: 8, children: [
            StatusChip(label: project.status),
            Text('${project.progressPercentage}% complete'),
          ]),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => showDialog(context: context, builder: (_) => _ProjectEditorDialog(existing: project))
                  .then((changed) {
                if (changed == true) ref.invalidate(_adminProjectsProvider);
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

class _ProjectEditorDialog extends ConsumerStatefulWidget {
  const _ProjectEditorDialog({this.existing});
  final SoftwareProject? existing;

  @override
  ConsumerState<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends ConsumerState<_ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _features;
  late final TextEditingController _architecture;
  late final TextEditingController _technologies;
  late final TextEditingController _githubUrl;
  late final TextEditingController _demoUrl;
  late final TextEditingController _lessonsLearned;
  late String _status;
  late double _progress;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _features = TextEditingController(text: e?.features.join(', ') ?? '');
    _architecture = TextEditingController(text: e?.architecture ?? '');
    _technologies = TextEditingController(text: e?.technologies.join(', ') ?? '');
    _githubUrl = TextEditingController(text: e?.githubUrl ?? '');
    _demoUrl = TextEditingController(text: e?.liveDemoUrl ?? '');
    _lessonsLearned = TextEditingController(text: e?.lessonsLearned ?? '');
    _status = validDropdownValue(e?.status, _projectStatuses);
    _progress = (e?.progressPercentage ?? 0).toDouble();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _features.dispose();
    _architecture.dispose();
    _technologies.dispose();
    _githubUrl.dispose();
    _demoUrl.dispose();
    _lessonsLearned.dispose();
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
      'features': parseCommaList(_features.text),
      'architecture': _architecture.text.trim(),
      'technologies': parseCommaList(_technologies.text),
      'github_url': _githubUrl.text.trim().isEmpty ? null : _githubUrl.text.trim(),
      'live_demo_url': _demoUrl.text.trim().isEmpty ? null : _demoUrl.text.trim(),
      'lessons_learned': _lessonsLearned.text.trim(),
      'status': _status,
      'progress_percentage': _progress.round(),
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/projects/admin', body: payload);
      } else {
        await client.put('/projects/admin/${widget.existing!.id}', body: payload);
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
      title: widget.existing == null ? 'New Project' : 'Edit Project',
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
        TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
        const SizedBox(height: 12),
        TextFormField(
          controller: _features,
          decoration: const InputDecoration(labelText: 'Features (comma-separated)'),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _architecture, decoration: const InputDecoration(labelText: 'Architecture'), maxLines: 2),
        const SizedBox(height: 12),
        TextFormField(
          controller: _technologies,
          decoration: const InputDecoration(labelText: 'Technologies (comma-separated)'),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _githubUrl, decoration: const InputDecoration(labelText: 'GitHub URL')),
        const SizedBox(height: 12),
        TextFormField(controller: _demoUrl, decoration: const InputDecoration(labelText: 'Live Demo URL')),
        const SizedBox(height: 12),
        TextFormField(
            controller: _lessonsLearned, decoration: const InputDecoration(labelText: 'Lessons Learned'), maxLines: 2),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final s in _projectStatuses) DropdownMenuItem(value: s, child: Text(s))],
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
    );
  }
}
