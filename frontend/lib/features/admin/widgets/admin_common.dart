import 'package:flutter/material.dart';

/// Shared confirmation dialog for every manager's delete action, so the
/// wording and button styling stay consistent across Research, Publications,
/// Projects, Blog, Skills, Timeline, Achievements, Gallery, and Media.
Future<bool> confirmDelete(BuildContext context, {required String title, required String message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
  return result ?? false;
}

/// Consistent header row (title + primary "add" action) at the top of every
/// manager page.
class ManagerHeader extends StatelessWidget {
  const ManagerHeader({super.key, required this.title, required this.addLabel, required this.onAdd});

  final String title;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel)),
      ],
    );
  }
}

/// Wraps a manager's editor dialog content with a consistent max size,
/// scroll behaviour, and Cancel/Save action row.
class EditorDialogShell extends StatelessWidget {
  const EditorDialogShell({
    super.key,
    required this.title,
    required this.formKey,
    required this.fields,
    required this.onSave,
    required this.saving,
    this.error,
    this.maxWidth = 640,
    this.maxHeight = 720,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final Future<void> Function() onSave;
  final bool saving;
  final String? error;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: fields),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: saving ? null : onSave,
                      child: saving
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

/// Parses a comma-separated text field into a trimmed, non-empty string list
/// — used for authors / technologies / features / tags fields across
/// managers instead of building a full chip-input widget for each.
List<String> parseCommaList(String input) =>
    input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// Every editor dialog seeds a `DropdownButtonFormField` from a hardcoded
/// options list using the record's existing value. If that value were ever
/// outside the known list (stale data, manual DB edit, enum drift between
/// frontend and backend), `DropdownButtonFormField` throws at build time
/// ("exactly zero or one item with [DropdownButton]'s value"). This falls
/// back to the first option instead, so the editor always opens — the worst
/// case is the field visibly resets to a default rather than crashing.
T validDropdownValue<T>(T? value, List<T> options) {
  if (value != null && options.contains(value)) return value;
  return options.first;
}
