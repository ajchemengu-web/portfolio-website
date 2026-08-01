import 'package:flutter/material.dart';

import 'responsive.dart';

/// Vertical page section with consistent spacing, an optional eyebrow/title
/// pair, and max-width centering. Every public page is built from a stack
/// of [Section] widgets so spacing stays consistent site-wide.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.background,
    this.maxWidth = 1200,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Color? background;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final content = MaxWidthBox(
      maxWidth: maxWidth,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 20 : 32,
        vertical: mobile ? 40 : 72,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
          ],
          if (subtitle != null) ...[
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
          ] else if (title != null)
            const SizedBox(height: 24),
          child,
        ],
      ),
    );

    if (background == null) return content;
    return ColoredBox(color: background!, child: content);
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Small rounded status indicator used for research/project status
/// ("Active", "Completed", "Published"...).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});
  final String label;

  Color _colorFor(String value, ColorScheme scheme) {
    switch (value.toLowerCase()) {
      case 'active':
        return scheme.primary;
      case 'completed':
      case 'published':
        return Colors.green.shade700;
      case 'planning':
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _colorFor(label, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.isEmpty ? label : label[0].toUpperCase() + label.substring(1),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Linear progress bar with a percentage label, used on research/project
/// cards to show completion.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.percentage});
  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percentage.clamp(0, 100) / 100,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$percentage%', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
