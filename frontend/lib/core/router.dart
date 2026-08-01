import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_page.dart';
import '../features/admin/achievement_manager/achievement_manager_page.dart';
import '../features/admin/auth/auth_controller.dart';
import '../features/admin/auth/login_page.dart';
import '../features/admin/blog_manager/blog_manager_page.dart';
import '../features/admin/dashboard/admin_shell.dart';
import '../features/admin/dashboard/dashboard_page.dart';
import '../features/admin/gallery_manager/gallery_manager_page.dart';
import '../features/admin/media_manager/media_manager_page.dart';
import '../features/admin/project_manager/project_manager_page.dart';
import '../features/admin/publication_manager/publication_manager_page.dart';
import '../features/admin/research_manager/research_manager_page.dart';
import '../features/admin/settings_manager/settings_manager_page.dart';
import '../features/admin/skills_manager/skills_manager_page.dart';
import '../features/admin/timeline_manager/timeline_manager_page.dart';
import '../features/awards/awards_page.dart';
import '../features/blog/blog_pages.dart';
import '../features/contact/contact_page.dart';
import '../features/downloads/downloads_page.dart';
import '../features/gallery/gallery_page.dart';
import '../features/home/home_page.dart';
import '../features/projects/project_pages.dart';
import '../features/publications/publications_page.dart';
import '../features/research/research_pages.dart';
import '../features/skills/skills_page.dart';
import '../features/timeline/timeline_page.dart';
import 'widgets/site_scaffold.dart';

/// Wraps every public route in [SiteScaffold] (shared nav + footer) while
/// keeping each page a plain, reusable widget.
Widget _publicPage(String path, Widget child) => SiteScaffold(currentPath: path, child: child);

/// Notifies GoRouter's `refresh` mechanism whenever admin auth status
/// changes, so `redirect` is re-evaluated without recreating the whole
/// [GoRouter] (which would otherwise reset navigation back to
/// [GoRouter.initialLocation] on every login/logout).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final goingToAdmin = state.matchedLocation.startsWith('/admin');
      final goingToLogin = state.matchedLocation == '/admin/login';

      if (!goingToAdmin) return null;

      // Auth status is still being restored from secure storage — don't
      // redirect yet, or an authenticated admin gets bounced to /login on
      // every page reload before restoration finishes.
      if (auth.status == AuthStatus.unknown) return null;

      if (!auth.isAuthenticated && !goingToLogin) return '/admin/login';
      if (auth.isAuthenticated && goingToLogin) return '/admin/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => _publicPage('/', const HomePage())),
      GoRoute(path: '/about', builder: (context, state) => _publicPage('/about', const AboutPage())),
      GoRoute(path: '/research', builder: (context, state) => _publicPage('/research', const ResearchListPage())),
      GoRoute(
        path: '/research/:slug',
        builder: (context, state) =>
            _publicPage('/research', ResearchDetailPage(slug: state.pathParameters['slug']!)),
      ),
      GoRoute(
          path: '/publications',
          builder: (context, state) => _publicPage('/publications', const PublicationsPage())),
      GoRoute(path: '/projects', builder: (context, state) => _publicPage('/projects', const ProjectsListPage())),
      GoRoute(
        path: '/projects/:slug',
        builder: (context, state) => _publicPage('/projects', ProjectDetailPage(slug: state.pathParameters['slug']!)),
      ),
      GoRoute(path: '/skills', builder: (context, state) => _publicPage('/skills', const SkillsPage())),
      GoRoute(path: '/timeline', builder: (context, state) => _publicPage('/timeline', const TimelinePage())),
      GoRoute(path: '/blog', builder: (context, state) => _publicPage('/blog', const BlogListPage())),
      GoRoute(
        path: '/blog/:slug',
        builder: (context, state) => _publicPage('/blog', BlogDetailPage(slug: state.pathParameters['slug']!)),
      ),
      GoRoute(path: '/awards', builder: (context, state) => _publicPage('/awards', const AwardsPage())),
      GoRoute(path: '/gallery', builder: (context, state) => _publicPage('/gallery', const GalleryPage())),
      GoRoute(path: '/downloads', builder: (context, state) => _publicPage('/downloads', const DownloadsPage())),
      GoRoute(path: '/contact', builder: (context, state) => _publicPage('/contact', const ContactPage())),

      // --- Admin ---
      GoRoute(path: '/admin/login', builder: (context, state) => const AdminLoginPage()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', redirect: (context, state) => '/admin/dashboard'),
          GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardPage()),
          GoRoute(path: '/admin/research', builder: (context, state) => const ResearchManagerPage()),
          GoRoute(path: '/admin/publications', builder: (context, state) => const PublicationManagerPage()),
          GoRoute(path: '/admin/projects', builder: (context, state) => const ProjectManagerPage()),
          GoRoute(path: '/admin/blog', builder: (context, state) => const BlogManagerPage()),
          GoRoute(path: '/admin/skills', builder: (context, state) => const SkillsManagerPage()),
          GoRoute(path: '/admin/timeline', builder: (context, state) => const TimelineManagerPage()),
          GoRoute(path: '/admin/achievements', builder: (context, state) => const AchievementManagerPage()),
          GoRoute(path: '/admin/gallery', builder: (context, state) => const GalleryManagerPage()),
          GoRoute(path: '/admin/media', builder: (context, state) => const MediaManagerPage()),
          GoRoute(path: '/admin/settings', builder: (context, state) => const SettingsManagerPage()),
        ],
      ),
    ],
  );
});
