import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/responsive.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

class ResearchListPage extends ConsumerWidget {
  const ResearchListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final research = ref.watch(researchListProvider);
    return Section(
      title: 'Research',
      subtitle: 'Active and completed research projects, organised from proposal to publication.',
      child: research.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load research projects: $e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No research projects published yet.');
          final columns = gridColumnsFor(context);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: columns == 1 ? 1.6 : 1.05,
            ),
            itemBuilder: (context, index) => _ResearchCard(project: items[index]),
          );
        },
      ),
    );
  }
}

class _ResearchCard extends StatelessWidget {
  const _ResearchCard({required this.project});
  final ResearchProject project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/research/${project.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (project.category != null)
                    Expanded(
                      child: Text(project.category!,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ),
                  StatusChip(label: project.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(project.title, style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  project.abstractText ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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

class ResearchDetailPage extends ConsumerWidget {
  const ResearchDetailPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(researchDetailProvider(slug));
    return Section(
      child: detail.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load this research project: $e'),
        data: (project) {
          if (project == null) return const EmptyView(message: 'Research project not found.', icon: Icons.search_off);
          return _ResearchDetailBody(project: project);
        },
      ),
    );
  }
}

class _ResearchDetailBody extends StatelessWidget {
  const _ResearchDetailBody({required this.project});
  final ResearchProject project;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/research'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Back to Research'),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusChip(label: project.status),
          if (project.category != null) Chip(label: Text(project.category!)),
        ]),
        const SizedBox(height: 16),
        Text(project.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        ProgressBar(percentage: project.progressPercentage),
        if (project.currentPhase != null) ...[
          const SizedBox(height: 8),
          Text('Current phase: ${project.currentPhase}', style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 32),
        if (project.abstractText != null) _DetailBlock('Abstract', project.abstractText!),
        if (project.researchQuestion != null) _DetailBlock('Research Question', project.researchQuestion!),
        if (project.motivation != null) _DetailBlock('Motivation', project.motivation!),
        if (project.objectives != null) _DetailBlock('Objectives', project.objectives!),
        if (project.methodology != null) _DetailBlock('Methodology', project.methodology!),
        if (project.results != null) _DetailBlock('Results', project.results!),
        if (project.futureWork != null) _DetailBlock('Future Work', project.futureWork!),
        if (project.ethicsStatement != null) _DetailBlock('Ethics Statement', project.ethicsStatement!),
        if (project.milestones.isNotEmpty) ...[
          Text('Progress Timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final milestone in project.milestones)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    milestone.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: milestone.isComplete ? Colors.green.shade700 : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(milestone.title, style: Theme.of(context).textTheme.bodyLarge)),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
        if (project.references.isNotEmpty) ...[
          Text('References', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final reference in project.references)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $reference', style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock(this.label, this.body);
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
