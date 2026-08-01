import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/responsive.dart';
import '../auth/auth_controller.dart';

class _AdminNavItem {
  const _AdminNavItem(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

const _navItems = [
  _AdminNavItem('Dashboard', '/admin/dashboard', Icons.dashboard_outlined),
  _AdminNavItem('Research Manager', '/admin/research', Icons.science_outlined),
  _AdminNavItem('Publication Manager', '/admin/publications', Icons.article_outlined),
  _AdminNavItem('Project Manager', '/admin/projects', Icons.code),
  _AdminNavItem('Blog Manager', '/admin/blog', Icons.rss_feed),
  _AdminNavItem('Skills Manager', '/admin/skills', Icons.psychology_outlined),
  _AdminNavItem('Timeline Manager', '/admin/timeline', Icons.timeline_outlined),
  _AdminNavItem('Achievement Manager', '/admin/achievements', Icons.emoji_events_outlined),
  _AdminNavItem('Gallery Manager', '/admin/gallery', Icons.photo_library_outlined),
  _AdminNavItem('Media / Download Manager', '/admin/media', Icons.folder_outlined),
  _AdminNavItem('Website Settings', '/admin/settings', Icons.settings_outlined),
];

/// Shell around every /admin/* route (except /admin/login): a persistent
/// side-nav on desktop / a drawer on mobile, plus a top bar with the
/// signed-in admin's email and a sign-out action. Access control itself is
/// enforced centrally in the router's redirect (core/router.dart) — this
/// widget assumes the caller is already authenticated.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final currentPath = GoRouterState.of(context).matchedLocation;
    final mobile = isMobile(context) || screenSizeOf(context) == ScreenSize.tablet;

    final nav = _AdminNav(currentPath: currentPath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          if (auth.email != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(auth.email!, style: Theme.of(context).textTheme.bodyMedium)),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      drawer: mobile ? Drawer(child: nav) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!mobile)
            SizedBox(
              width: 240,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: nav,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNav extends StatelessWidget {
  const _AdminNav({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        for (final item in _navItems)
          ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            selected: currentPath == item.path,
            onTap: () => context.go(item.path),
          ),
      ],
    );
  }
}
