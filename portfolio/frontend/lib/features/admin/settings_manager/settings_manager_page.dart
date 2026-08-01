import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/widgets/common.dart';
import '../auth/auth_controller.dart';

final _adminSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/settings/admin');
  return Map<String, dynamic>.from(result as Map);
});

/// Website Settings: homepage text, SEO, social links, contact info,
/// theme, and the file references for resume/logo/favicon — a flat
/// key/value store (backend: app/api/settings.py) so new settings can be
/// added without a migration.
class SettingsManagerPage extends ConsumerStatefulWidget {
  const SettingsManagerPage({super.key});

  @override
  ConsumerState<SettingsManagerPage> createState() => _SettingsManagerPageState();
}

class _SettingsManagerPageState extends ConsumerState<SettingsManagerPage> {
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  String? _error;
  String? _saved;
  bool _hydrated = false;

  static const _fields = [
    ('homepage_headline', 'Homepage Headline'),
    ('homepage_subheadline', 'Homepage Subheadline'),
    ('seo_title', 'SEO Title'),
    ('seo_description', 'SEO Description'),
    ('contact_email', 'Contact Email'),
    ('github_url', 'GitHub URL'),
    ('linkedin_url', 'LinkedIn URL'),
    ('analytics_id', 'Analytics ID (optional)'),
  ];

  TextEditingController _controllerFor(String key) => _controllers.putIfAbsent(key, () => TextEditingController());

  void _hydrate(Map<String, dynamic> settings) {
    if (_hydrated) return;
    for (final (key, _) in _fields) {
      final value = settings[key];
      _controllerFor(key).text = value == null ? '' : value.toString();
    }
    // social_links is stored as a nested object; unpack into the two flat fields above.
    final socialLinks = settings['social_links'];
    if (socialLinks is Map) {
      _controllerFor('github_url').text = (socialLinks['github'] ?? '').toString();
      _controllerFor('linkedin_url').text = (socialLinks['linkedin'] ?? '').toString();
    }
    _hydrated = true;
  }

  Future<void> _saveAll() async {
    setState(() {
      _saving = true;
      _error = null;
      _saved = null;
    });

    final client = ref.read(adminApiClientProvider);
    try {
      for (final (key, _) in _fields) {
        if (key == 'github_url' || key == 'linkedin_url') continue; // saved via social_links below
        await client.put('/settings/admin/$key', body: {'value': _controllerFor(key).text.trim()});
      }
      await client.put('/settings/admin/social_links', body: {
        'value': {
          'github': _controllerFor('github_url').text.trim(),
          'linkedin': _controllerFor('linkedin_url').text.trim(),
        },
      });
      setState(() => _saved = 'Settings saved.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on ApiUnreachableException {
      setState(() => _error = 'Could not reach the API.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(_adminSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Website Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Controls the public site\'s homepage text, SEO metadata, and contact/social links.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        settings.when(
          loading: () => const LoadingView(),
          error: (e, st) =>
              ErrorView(message: 'Could not load settings: $e', onRetry: () => ref.invalidate(_adminSettingsProvider)),
          data: (data) {
            _hydrate(data);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (key, label) in _fields) ...[
                    TextField(controller: _controllerFor(key), decoration: InputDecoration(labelText: label)),
                    const SizedBox(height: 16),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (_saved != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_saved!, style: TextStyle(color: Colors.green.shade700)),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _saveAll,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Settings'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
