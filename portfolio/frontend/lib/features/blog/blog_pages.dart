import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/common.dart';
import '../../data/api_repository.dart';
import '../../data/models.dart';

class BlogListPage extends ConsumerStatefulWidget {
  const BlogListPage({super.key});

  @override
  ConsumerState<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends ConsumerState<BlogListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(blogListProvider);
    return Section(
      title: 'Blog',
      subtitle: 'Technical articles, research notes, tutorials, and learning reflections.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(hintText: 'Search articles…', prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 24),
          posts.when(
            loading: () => const LoadingView(),
            error: (e, st) => ErrorView(message: 'Could not load the blog: $e'),
            data: (items) {
              final filtered = _query.isEmpty
                  ? items
                  : items
                      .where((p) =>
                          p.title.toLowerCase().contains(_query) ||
                          (p.excerpt ?? '').toLowerCase().contains(_query) ||
                          p.tags.any((t) => t.toLowerCase().contains(_query)))
                      .toList();
              if (filtered.isEmpty) return const EmptyView(message: 'No articles match your search.');
              return Column(children: [for (final post in filtered) _BlogTile(post: post)]);
            },
          ),
        ],
      ),
    );
  }
}

class _BlogTile extends StatelessWidget {
  const _BlogTile({required this.post});
  final BlogPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/blog/${post.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, children: [
                if (post.category != null) Chip(label: Text(post.category!)),
                if (post.publishedAt != null)
                  Text(DateFormat.yMMMd().format(post.publishedAt!), style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 10),
              Text(post.title, style: Theme.of(context).textTheme.titleLarge),
              if (post.excerpt != null) ...[
                const SizedBox(height: 8),
                Text(post.excerpt!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, children: [for (final tag in post.tags) Chip(label: Text('#$tag'))]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class BlogDetailPage extends ConsumerWidget {
  const BlogDetailPage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(blogDetailProvider(slug));
    return Section(
      maxWidth: 860,
      child: detail.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: 'Could not load this article: $e'),
        data: (post) {
          if (post == null) return const EmptyView(message: 'Article not found.', icon: Icons.search_off);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/blog'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Blog'),
              ),
              const SizedBox(height: 8),
              Text(post.title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              if (post.publishedAt != null)
                Text(DateFormat.yMMMMd().format(post.publishedAt!), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              MarkdownBody(data: post.contentMarkdown ?? post.excerpt ?? ''),
            ],
          );
        },
      ),
    );
  }
}
