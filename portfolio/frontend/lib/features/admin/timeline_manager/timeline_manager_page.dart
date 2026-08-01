import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../../../data/api_repository.dart';
import '../../../data/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/admin_common.dart';

const _eventTypes = [
  'education', 'award', 'research_milestone', 'internship',
  'project', 'leadership', 'publication', 'scholarship',
];

class TimelineManagerPage extends ConsumerWidget {
  const TimelineManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(timelineProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ManagerHeader(title: 'Timeline Manager', addLabel: 'New Event', onAdd: () => _openEditor(context, ref)),
        const SizedBox(height: 24),
        timeline.when(
          loading: () => const LoadingView(),
          error: (e, st) =>
              ErrorView(message: 'Could not load the timeline: $e', onRetry: () => ref.invalidate(timelineProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No timeline events yet — add the first one.');
            return Column(children: [for (final event in items) _AdminTimelineTile(event: event)]);
          },
        ),
      ],
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, [TimelineEvent? existing]) {
    showDialog(context: context, builder: (_) => _TimelineEditorDialog(existing: existing)).then((changed) {
      if (changed == true) ref.invalidate(timelineProvider);
    });
  }
}

class _AdminTimelineTile extends ConsumerWidget {
  const _AdminTimelineTile({required this.event});
  final TimelineEvent event;

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final confirmed =
        await confirmDelete(context, title: 'Delete event?', message: '"${event.title}" will be permanently deleted.');
    if (!confirmed) return;
    final client = ref.read(adminApiClientProvider);
    await client.delete('/timeline/admin/${event.id}');
    ref.invalidate(timelineProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(event.title),
        subtitle: Text('${event.eventType.replaceAll('_', ' ')} · ${DateFormat.yMMMd().format(event.eventDate)}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  showDialog(context: context, builder: (_) => _TimelineEditorDialog(existing: event)).then((changed) {
                if (changed == true) ref.invalidate(timelineProvider);
              }),
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(ref, context)),
          ],
        ),
      ),
    );
  }
}

class _TimelineEditorDialog extends ConsumerStatefulWidget {
  const _TimelineEditorDialog({this.existing});
  final TimelineEvent? existing;

  @override
  ConsumerState<_TimelineEditorDialog> createState() => _TimelineEditorDialogState();
}

class _TimelineEditorDialogState extends ConsumerState<_TimelineEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _eventType;
  late DateTime _eventDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _eventType = validDropdownValue(e?.eventType, _eventTypes);
    _eventDate = e?.eventDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _eventDate = picked);
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
      'event_type': _eventType,
      'event_date': '${_eventDate.year.toString().padLeft(4, '0')}-'
          '${_eventDate.month.toString().padLeft(2, '0')}-'
          '${_eventDate.day.toString().padLeft(2, '0')}',
    };

    final client = ref.read(adminApiClientProvider);
    try {
      if (widget.existing == null) {
        await client.post('/timeline/admin', body: payload);
      } else {
        await client.put('/timeline/admin/${widget.existing!.id}', body: payload);
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
      title: widget.existing == null ? 'New Timeline Event' : 'Edit Timeline Event',
      formKey: _formKey,
      saving: _saving,
      error: _error,
      onSave: _save,
      maxHeight: 560,
      fields: [
        TextFormField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _eventType,
          decoration: const InputDecoration(labelText: 'Event Type'),
          items: [for (final t in _eventTypes) DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')))],
          onChanged: (v) => setState(() => _eventType = v ?? _eventType),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date'),
          subtitle: Text(DateFormat.yMMMd().format(_eventDate)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickDate,
        ),
      ],
    );
  }
}
