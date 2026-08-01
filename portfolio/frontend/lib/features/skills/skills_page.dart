import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

const Map<String, String> _categoryLabels = {
  'programming_languages': 'Programming Languages',
  'frameworks': 'Frameworks',
  'cloud': 'Cloud',
  'databases': 'Databases',
  'cybersecurity': 'Cybersecurity',
  'artificial_intelligence': 'Artificial Intelligence',
  'operating_systems': 'Operating Systems',
  'tools': 'Tools',
};

class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillsProvider);
    return Section(
      title: 'Technical Skills',
      subtitle: 'Proficiency shown out of 5, based on hands-on project and research experience.',
      child: skills.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load skills: $e'),
        data: (grouped) {
          if (grouped.values.every((v) => v.isEmpty)) {
            return const EmptyView(message: 'No skills listed yet.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in grouped.entries)
                if (entry.value.isNotEmpty) _CategorySection(category: entry.key, skills: entry.value),
            ],
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.skills});
  final String category;
  final List<Skill> skills;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_categoryLabels[category] ?? category, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final skill in skills) _SkillCard(skill: skill)],
          ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});
  final Skill skill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(skill.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= skill.proficiencyLevel ? Icons.circle : Icons.circle_outlined,
                  size: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ].expand((w) => [w, const SizedBox(width: 4)]).toList(),
          ),
          if (skill.yearsExperience != null) ...[
            const SizedBox(height: 6),
            Text('${skill.yearsExperience!.toStringAsFixed(1)} yrs experience',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
