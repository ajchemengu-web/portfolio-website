import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/api_repository.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _achievementCategories = ['academic', 'competition', 'leadership', 'scholarship', 'certificate'];

class AchievementManagerPage extends ConsumerWidget {
  const AchievementManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Achievement Manager', addLabel: 'New Achievement', onAdd: () => _openEditor(context, ref)),
        const SizedBox(height: 24),
        achievements.when(
          loading: () => const LoadingView(),
          error: (e, st) =>
              ErrorView(message: 'Could not load achievements: $e', onRetry: () => ref.invalidate(achievementsProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No achievements yet — add the first one.');
            return Column(children: [for (final a in items) _AdminAchievementTile(achievement: a)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [Achievement? existing]) {
    showDialog(context: context, builder: (_) => _AchievementEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(achievementsProvider);
    });
  }
}

class _AdminAchievementTile extends ConsumerWidget {
  const _AdminAchievementTile({required this.achievement});
  final Achievement achievement;

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed = await confirmDelete(context,
        title: 'Delete achievement?', message: '"${achievement.title}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/achievements/admin/${achievement.id}');
    ref.invalidate(achievementsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(achievement.title),
        subtitle: Text([
          achievement.category,
          if (achievement.issuer != null) achievement.issuer!,
          if (achievement.dateAwarded != null) DateFormat.yMMM().format(achievement.dateAwarded!),
        ].join(' · ')),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showDialog(context: context, builder: (_) => _AchievementEditorDialog(existing: achievement))
                  .then((changed) {
                if (changed == true) ref.invalidate(achievementsProvider);
              }),
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _AchievementEditorDialog extends ConsumerStatefulWidget {
  const _AchievementEditorDialog({this.existing});
  final Achievement? existing;

  @override
  ConsumerState<_AchievementEditorDialog> createState() => _AchievementEditorDialogState();
}

class _AchievementEditorDialogState extends ConsumerState<_AchievementEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _issuer;
  late String _category;
  DateTime? _dateAwarded;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _issuer = TextEditingController(text: e?.issuer ?? '');
    _category = validDropdownValue(e?.category, _achievementCategories);
    _dateAwarded = e?.dateAwarded;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _issuer.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateAwarded ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateAwarded = picked);
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
      'category': _category,
      'issuer': _issuer.text.trim(),
      if (_dateAwarded != null)
        'date_awarded': '${_dateAwarded!.year.toString().padLeft(4, '0')}-'
            '${_dateAwarded!.month.toString().padLeft(2, '0')}-'
            '${_dateAwarded!.day.toString().padLeft(2, '0')}',
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/achievements/admin', body: payload);
      } else {
        await client.put('/achievements/admin/${widget.existing!.id}', body: payload);
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
      title: widget.existing == null ? 'New Achievement' : 'Edit Achievement',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      onSave: _save,
      maxHeight: 600,
      fields: [
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
        const SizedBox(height: 12),
        TextFormField(controller: _issuer, decoration: const InputDecoration(labelText: 'Issuer')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in _achievementCategories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date awarded'),
          subtitle: Text(_dateAwarded == null ? 'Not set' : DateFormat.yMMMd().format(_dateAwarded!)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickDate,
        ),
      ],
    );
  }
}
