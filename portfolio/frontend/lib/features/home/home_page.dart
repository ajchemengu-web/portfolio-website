import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/responsive.dart';
import '../../data/api_repository.dart';
import '../../data/placeholder_data.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const _HeroSection(),
        Section(
          title: 'Research Interests',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              Chip(label: Text('Federated & Privacy-Preserving ML')),
              Chip(label: Text('Explainable AI')),
              Chip(label: Text('Network & IoT Security')),
              Chip(label: Text('Low-Resource NLP')),
            ],
          ),
        ),
        Section(
          title: 'Current Research',
          subtitle: 'A snapshot of what I\'m actively working on right now.',
          child: _ResearchPreview(ref: ref),
        ),
        Section(
          title: 'Featured Publication & Latest Article',
          background: Theme.of(context).colorScheme.surfaceContainerLow,
          child: _FeaturedRow(ref: ref),
        ),
        Section(
          child: Center(
            child: Column(
              children: [
                Text('Want to know more?', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(onPressed: () => context.go('/research'), child: const Text('Browse Research')),
                    OutlinedButton(onPressed: () => context.go('/contact'), child: const Text('Get in Touch')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mobile = isMobile(context);
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      child: Section(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi, I\'m ${AppConfig.siteName}.',
                style: (mobile ? Theme.of(context).textTheme.headlineMedium : Theme.of(context).textTheme.displaySmall)),
            const SizedBox(height: 12),
            Text(
              AppConfig.siteTagline,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(placeholderBio.trim().split('\n\n').first, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                FilledButton(onPressed: () => context.go('/research'), child: const Text('View My Research')),
                OutlinedButton(onPressed: () => context.go('/downloads'), child: const Text('Download CV')),
                OutlinedButton(onPressed: () => context.go('/contact'), child: const Text('Contact Me')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchPreview extends StatelessWidget {
  const _ResearchPreview({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final research = ref.watch(researchListProvider);
    return research.when(
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(message: 'Could not load research: $e'),
      data: (items) {
        final active = items.where((r) => r.status == 'active').take(3).toList();
        final shown = active.isEmpty ? items.take(3).toList() : active;
        if (shown.isEmpty) return const EmptyView(message: 'No research projects published yet.');
        return Column(
          children: [
            for (final project in shown) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(project.title, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(project.abstractText ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  trailing: StatusChip(label: project.status),
                  onTap: () => GoRouter.of(context).go('/research/${project.slug}'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _FeaturedRow extends StatelessWidget {
  const _FeaturedRow({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final publications = ref.watch(publicationsListProvider);
    final posts = ref.watch(blogListProvider);
    final mobile = isMobile(context);

    final pubCard = publications.when(
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(message: 'Could not load publications.'),
      data: (items) => items.isEmpty
          ? const EmptyView(message: 'No publications yet.')
          : _FeatureCard(
              label: 'Featured Publication',
              title: items.first.title,
              body: items.first.abstractText ?? '',
              onTap: () => GoRouter.of(context).go('/publications'),
            ),
    );

    final postCard = posts.when(
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(message: 'Could not load the blog.'),
      data: (items) => items.isEmpty
          ? const EmptyView(message: 'No articles published yet.')
          : _FeatureCard(
              label: 'Latest Article',
              title: items.first.title,
              body: items.first.excerpt ?? '',
              onTap: () => GoRouter.of(context).go('/blog/${items.first.slug}'),
            ),
    );

    if (mobile) {
      return Column(children: [pubCard, const SizedBox(height: 16), postCard]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: pubCard),
        const SizedBox(width: 24),
        Expanded(child: postCard),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.label, required this.title, required this.body, required this.onTap});
  final String label;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
