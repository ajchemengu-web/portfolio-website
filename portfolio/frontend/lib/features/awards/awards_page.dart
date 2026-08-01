import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/common.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

const Map<String, IconData> _categoryIcons = {
  'academic': Icons.school_outlined,
  'competition': Icons.emoji_events_outlined,
  'leadership': Icons.groups_outlined,
  'scholarship': Icons.card_giftcard_outlined,
  'certificate': Icons.verified_outlined,
};

class AwardsPage extends ConsumerWidget {
  const AwardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    return Section(
      title: 'Awards & Achievements',
      subtitle: 'Academic awards, competitions, leadership, scholarships, and certifications.',
      child: achievements.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load achievements: $e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No achievements listed yet.');
          return Column(children: [for (final item in items) _AchievementTile(achievement: item)]);
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_categoryIcons[achievement.category] ?? Icons.star_outline, color: scheme.onPrimaryContainer),
        ),
        title: Text(achievement.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (achievement.issuer != null) Text(achievement.issuer!),
            if (achievement.description != null) Text(achievement.description!),
          ],
        ),
        trailing: achievement.dateAwarded != null
            ? Text(DateFormat.yMMM().format(achievement.dateAwarded!), style: Theme.of(context).textTheme.bodySmall)
            : null,
      ),
    );
  }
}
