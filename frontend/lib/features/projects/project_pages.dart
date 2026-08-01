import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/widgets/common.dart';
import '../../core/widgets/responsive.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

class ProjectsListPage extends ConsumerWidget {
  const ProjectsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsListProvider);
    return Section(
      title: 'Software Projects',
      subtitle: 'Things I\'ve built — from research tooling to full applications.',
      child: projects.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load projects: $e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No projects published yet.');
          final columns = gridColumnsFor(context);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: columns == 1 ? 1.5 : 1.0,
            ),
            itemBuilder: (context, index) => _ProjectCard(project: items[index]),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final SoftwareProject project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/projects/${project.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(project.title, style: Theme.of(context).textTheme.titleLarge)),
                StatusChip(label: project.status),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: Text(project.description ?? '', maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 12),
              if (project.technologies.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final tech in project.technologies.take(5)) Chip(label: Text(tech))],
                ),
              const SizedBox(height: 12),
              ProgressBar(percentage: project.progressPercentage),
            ],
          ),
        ),
      ),
    );
  }
}

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(projectDetailProvider(slug));
    return Section(
      child: detail.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load this project: $e'),
        data: (project) {
          if (project == null) return const EmptyView(message: 'Project not found.', icon: Icons.search_off);
          return _ProjectDetailBody(project: project);
        },
      ),
    );
  }
}

class _ProjectDetailBody extends StatelessWidget {
  const _ProjectDetailBody({required this.project});
  final SoftwareProject project;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/projects'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to Projects'),
        ),
        const SizedBox(height: 8),
        StatusChip(label: project.status),
        const SizedBox(height: 16),
        Text(project.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        ProgressBar(percentage: project.progressPercentage),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (project.githubUrl != null)
            OutlinedButton.icon(
              onPressed: () => launcher.launchUrl(Uri.parse(project.githubUrl!), webOnlyWindowName: '_blank'),
              icon: const Icon(Icons.code, size: 18),
              label: const Text('View on GitHub'),
            ),
          if (project.liveDemoUrl != null)
            FilledButton.icon(
              onPressed: () => launcher.launchUrl(Uri.parse(project.liveDemoUrl!), webOnlyWindowName: '_blank'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Live Demo'),
            ),
        ]),
        const SizedBox(height: 32),
        if (project.description != null) _Block('Overview', project.description!),
        if (project.features.isNotEmpty) ...[
          Text('Features', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final f in project.features)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $f')),
          const SizedBox(height: 24),
        ],
        if (project.architecture != null) _Block('Architecture', project.architecture!),
        if (project.technologies.isNotEmpty) ...[
          Text('Technologies', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final t in project.technologies) Chip(label: Text(t))]),
          const SizedBox(height: 24),
        ],
        if (project.lessonsLearned != null) _Block('Lessons Learned', project.lessonsLearned!),
        if (project.futureImprovements != null) _Block('Future Improvements', project.futureImprovements!),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.label, this.body);
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
