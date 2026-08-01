import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/api_repository.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _skillCategories = [
  'programming_languages', 'frameworks', 'cloud', 'databases',
  'cybersecurity', 'artificial_intelligence', 'operating_systems', 'tools',
];

class SkillsManagerPage extends ConsumerWidget {
  const SkillsManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Skills Manager', addLabel: 'New Skill', onAdd: () => _openEditor(context, ref)),
        const SizedBox(height: 24),
        skills.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(message: 'Could not load skills: $e', onRetry: () => ref.invalidate(skillsProvider)),
          data: (grouped) {
            final all = grouped.values.expand((v) => v).toList();
            if (all.isEmpty) return const EmptyView(message: 'No skills listed yet — add the first one.');
            return Column(children: [for (final skill in all) _AdminSkillTile(skill: skill)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [Skill? existing]) {
    showDialog(context: context, builder: (_) => _SkillEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(skillsProvider);
    });
  }
}

class _AdminSkillTile extends ConsumerWidget {
  const _AdminSkillTile({required this.skill});
  final Skill skill;

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed =
        await confirmDelete(context, title: 'Delete skill?', message: '"${skill.name}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/skills/admin/${skill.id}');
    ref.invalidate(skillsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(skill.name),
        subtitle: Text('${skill.category.replaceAll('_', ' ')} · Level ${skill.proficiencyLevel}/5'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  showDialog(context: context, builder: (_) => _SkillEditorDialog(existing: skill)).then((changed) {
                if (changed == true) ref.invalidate(skillsProvider);
              }),
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _SkillEditorDialog extends ConsumerStatefulWidget {
  const _SkillEditorDialog({this.existing});
  final Skill? existing;

  @override
  ConsumerState<_SkillEditorDialog> createState() => _SkillEditorDialogState();
}

class _SkillEditorDialogState extends ConsumerState<_SkillEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _years;
  late String _category;
  late double _level;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _years = TextEditingController(text: e?.yearsExperience?.toString() ?? '');
    _category = validDropdownValue(e?.category, _skillCategories);
    _level = (e?.proficiencyLevel ?? 3).toDouble();
  }

  @override
  void dispose() {
    _name.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = {
      'name': _name.text.trim(),
      'category': _category,
      'proficiency_level': _level.round(),
      if (_years.text.trim().isNotEmpty) 'years_experience': double.tryParse(_years.text.trim()),
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/skills/admin', body: payload);
      } else {
        await client.put('/skills/admin/${widget.existing!.id}', body: payload);
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
      title: widget.existing == null ? 'New Skill' : 'Edit Skill',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      onSave: _save,
      maxHeight: 480,
      fields: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in _skillCategories) DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _years,
          decoration: const InputDecoration(labelText: 'Years of experience (optional)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        Text('Proficiency: ${_level.round()} / 5'),
        Slider(
          value: _level,
          min: 1,
          max: 5,
          divisions: 4,
          label: '${_level.round()}',
          onChanged: (v) => setState(() => _level = v),
        ),
      ],
    );
  }
}
