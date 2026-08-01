import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants.dart';
import 'responsive.dart';

class NavItem {
  const NavItem(this.label, this.path);
  final String label;
  final String path;
}

const List<NavItem> kPublicNavItems = [
  NavItem('Home', '/'),
  NavItem('About', '/about'),
  NavItem('Research', '/research'),
  NavItem('Publications', '/publications'),
  NavItem('Projects', '/projects'),
  NavItem('Skills', '/skills'),
  NavItem('Timeline', '/timeline'),
  NavItem('Blog', '/blog'),
  NavItem('Awards', '/awards'),
  NavItem('Gallery', '/gallery'),
  NavItem('Downloads', '/downloads'),
  NavItem('Contact', '/contact'),
];

/// Shared chrome (top nav + footer) for every public page. Collapses to a
/// hamburger drawer below the tablet breakpoint.
class SiteScaffold extends StatelessWidget {
  const SiteScaffold({super.key, required this.child, required this.currentPath});

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context) || screenSizeOf(context) == ScreenSize.tablet;

    return Scaffold(
      appBar: _SiteAppBar(currentPath: currentPath, showMenuButton: mobile),
      drawer: mobile ? _SiteDrawer(currentPath: currentPath) : null,
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          children: [
            child,
            const _SiteFooter(),
          ],
        ),
      ),
    );
  }
}

class _SiteAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SiteAppBar({required this.currentPath, required this.showMenuButton});

  final String currentPath;
  final bool showMenuButton;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 72,
      titleSpacing: showMenuButton ? 0 : 32,
      leading: showMenuButton
          ? Builder(builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ))
          : null,
      title: InkWell(
        onTap: () => context.go('/'),
        child: Text(
          AppConfig.siteName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      actions: showMenuButton
          ? [const SizedBox(width: 8)]
          : [
              for (final item in kPublicNavItems)
                _NavButton(item: item, active: currentPath == item.path),
              const SizedBox(width: 16),
            ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.active});
  final NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () => context.go(item.path),
      style: TextButton.styleFrom(
        foregroundColor: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
      child: Text(item.label, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
    );
  }
}

class _SiteDrawer extends StatelessWidget {
  const _SiteDrawer({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(AppConfig.siteName, style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            for (final item in kPublicNavItems)
              ListTile(
                title: Text(item.label),
                selected: currentPath == item.path,
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = DateTime.now().year;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Text(AppConfig.siteName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(AppConfig.siteTagline, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              alignment: WrapAlignment.center,
              children: [
                TextButton(onPressed: () {}, child: const Text('GitHub')),
                TextButton(onPressed: () {}, child: const Text('LinkedIn')),
                TextButton(
                  onPressed: () => GoRouter.of(context).go('/contact'),
                  child: const Text('Contact'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('© $year ${AppConfig.siteName}. All rights reserved.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
