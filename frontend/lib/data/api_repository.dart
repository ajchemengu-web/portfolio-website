/// Read-only data providers for every public page. Each provider tries the
/// live API first and falls back to bundled placeholder content on any
/// failure (network error, backend not deployed yet, unexpected shape) —
/// see AppConfig / placeholder_data.dart for the rationale. This keeps the
/// public site demo-able and reviewable at any point in development.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../features/admin/auth/auth_controller.dart';
import 'models.dart';
import 'placeholder_data.dart';

Future<T> _withFallback<T>(Future<T> Function() call, T Function() fallback, {String? label}) async {
  try {
    return await call();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[api_repository] ${label ?? ''} falling back to placeholder data: $e');
    }
    return fallback();
  }
}

List<T> _items<T>(dynamic json, T Function(Map<String, dynamic>) parse) {
  return Paginated<T>.fromJson(Map<String, dynamic>.from(json as Map), parse).items;
}

final researchListProvider = FutureProvider<List<ResearchProject>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/research', query: {'page_size': 50}), ResearchProject.fromJson),
    () => placeholderResearch,
    label: 'research',
  );
});

final researchDetailProvider = FutureProvider.family<ResearchProject?, String>((ref, slug) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => ResearchProject.fromJson(Map<String, dynamic>.from(await client.get('/research/$slug') as Map)),
    () => placeholderResearch.where((p) => p.slug == slug).firstOrNull,
    label: 'research/$slug',
  );
});

final publicationsListProvider = FutureProvider<List<Publication>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/publications', query: {'page_size': 50}), Publication.fromJson),
    () => placeholderPublications,
    label: 'publications',
  );
});

final projectsListProvider = FutureProvider<List<SoftwareProject>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/projects', query: {'page_size': 50}), SoftwareProject.fromJson),
    () => placeholderProjects,
    label: 'projects',
  );
});

final projectDetailProvider = FutureProvider.family<SoftwareProject?, String>((ref, slug) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => SoftwareProject.fromJson(Map<String, dynamic>.from(await client.get('/projects/$slug') as Map)),
    () => placeholderProjects.where((p) => p.slug == slug).firstOrNull,
    label: 'projects/$slug',
  );
});

final blogListProvider = FutureProvider<List<BlogPost>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/blog', query: {'page_size': 50}), BlogPost.fromJson),
    () => placeholderBlogPosts,
    label: 'blog',
  );
});

final blogDetailProvider = FutureProvider.family<BlogPost?, String>((ref, slug) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => BlogPost.fromJson(Map<String, dynamic>.from(await client.get('/blog/$slug') as Map)),
    () => placeholderBlogPosts.where((p) => p.slug == slug).firstOrNull,
    label: 'blog/$slug',
  );
});

final skillsProvider = FutureProvider<Map<String, List<Skill>>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async {
      final raw = Map<String, dynamic>.from(await client.get('/skills') as Map);
      return raw.map((key, value) => MapEntry(
            key,
            (value as List).map((e) => Skill.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
          ));
    },
    () => placeholderSkills,
    label: 'skills',
  );
});

final timelineProvider = FutureProvider<List<TimelineEvent>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/timeline', query: {'page_size': 100}), TimelineEvent.fromJson),
    () => placeholderTimeline,
    label: 'timeline',
  );
});

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/achievements', query: {'page_size': 100}), Achievement.fromJson),
    () => placeholderAchievements,
    label: 'achievements',
  );
});

final galleryProvider = FutureProvider<List<GalleryItem>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/gallery', query: {'page_size': 100}), GalleryItem.fromJson),
    () => placeholderGallery,
    label: 'gallery',
  );
});

final downloadsProvider = FutureProvider<List<DownloadFile>>((ref) async {
  final client = ref.watch(publicApiClientProvider);
  return _withFallback(
    () async => _items(await client.get('/downloads', query: {'page_size': 100}), DownloadFile.fromJson),
    () => placeholderDownloads,
    label: 'downloads',
  );
});

/// Submits the public contact form. Deliberately *not* wrapped in the
/// placeholder-fallback pattern above — a failed submission must be
/// reported to the user truthfully rather than silently "succeeding"
/// against fake data.
Future<void> submitContactForm(
  ApiClient client, {
  required String name,
  required String email,
  String? subject,
  required String message,
}) async {
  await client.post('/contact', body: {
    'name': name,
    'email': email,
    if (subject != null && subject.isNotEmpty) 'subject': subject,
    'message': message,
  });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
