import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/common.dart';
import '../auth/auth_controller.dart';

final _dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/admin/dashboard');
  return Map<String, dynamic>.from((result as Map)['counts'] as Map);
});

final _recentActivityProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(adminApiClientProvider);
  final result = await client.get('/admin/activity', query: {'page_size': 10});
  return ((result as Map)['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_dashboardStatsProvider);
    final activity = ref.watch(_recentActivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Everything below is manageable from this dashboard — no code changes required.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        stats.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(
            message: 'Could not load dashboard stats: $e',
            onRetry: () => ref.invalidate(_dashboardStatsProvider),
          ),
          data: (counts) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(label: 'Research Projects', value: counts['research_projects'], icon: Icons.science_outlined),
              _StatCard(label: 'Research Drafts', value: counts['research_drafts'], icon: Icons.edit_note),
              _StatCard(label: 'Publications', value: counts['publications'], icon: Icons.article_outlined),
              _StatCard(label: 'Software Projects', value: counts['software_projects'], icon: Icons.code),
              _StatCard(label: 'Blog Posts', value: counts['blog_posts'], icon: Icons.rss_feed),
              _StatCard(label: 'Unread Messages', value: counts['unread_messages'], icon: Icons.mail_outline),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/research'),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Research'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/publications'),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Publications'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/projects'),
              icon: const Icon(Icons.code),
              label: const Text('Projects'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/blog'),
              icon: const Icon(Icons.rss_feed),
              label: const Text('Blog'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/media'),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Media'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        activity.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(message: 'Could not load recent activity: $e'),
          data: (items) {
            if (items.isEmpty) return const EmptyView(message: 'No activity yet.');
            return Card(
              child: Column(
                children: [
                  for (final entry in items)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text('${entry['action']} · ${entry['entity_type']}'),
                      subtitle: Text(entry['created_at'] != null
                          ? DateFormat.yMMMd().add_jm().format(DateTime.parse(entry['created_at'] as String))
                          : ''),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final dynamic value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('${value ?? 0}', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
