import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/common.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

const Map<String, IconData> _eventIcons = {
  'education': Icons.school_outlined,
  'award': Icons.emoji_events_outlined,
  'research_milestone': Icons.science_outlined,
  'internship': Icons.work_outline,
  'project': Icons.code,
  'leadership': Icons.groups_outlined,
  'publication': Icons.article_outlined,
  'scholarship': Icons.card_giftcard_outlined,
};

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(timelineProvider);
    return Section(
      title: 'Timeline',
      subtitle: 'Education, research milestones, internships, and leadership — in chronological order.',
      child: timeline.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load the timeline: $e'),
        data: (events) {
          if (events.isEmpty) return const EmptyView(message: 'No timeline events yet.');
          return Column(children: [for (final e in events) _TimelineTile(event: e)]);
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});
  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primaryContainer,
                child: Icon(_eventIcons[event.eventType] ?? Icons.circle, size: 18, color: scheme.onPrimaryContainer),
              ),
              Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat.yMMMM().format(event.eventDate), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(event.title, style: Theme.of(context).textTheme.titleMedium),
                  if (event.description != null) ...[
                    const SizedBox(height: 4),
                    Text(event.description!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
