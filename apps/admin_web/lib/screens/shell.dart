import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../providers.dart';
import '../theme.dart';

/// Persistent nav rail + header around the admin sections.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.child, super.key});
  final Widget child;

  static const _destinations = [
    (label: 'Tournaments', icon: Icons.emoji_events_outlined, path: '/tournaments'),
    (label: 'Economy', icon: Icons.tune, path: '/economy'),
  ];

  int _indexForLocation(String location) {
    if (location.startsWith('/economy')) return 1;
    return 0; // tournaments (incl. /tournaments/new)
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _indexForLocation(location);
    final email = ref.watch(sessionProvider)?.user.email ?? '';

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (i) =>
                context.go(_destinations[i].path),
            backgroundColor: AppColors.felt,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.shield_moon_outlined,
                      color: AppColors.gold, size: 30),
                  const SizedBox(height: 6),
                  Text(AdminConfig.envLabel,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          letterSpacing: 1)),
                ],
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _Header(email: email),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 60,
      color: AppColors.felt,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text('Gathr Admin',
              style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(email, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () =>
                ref.read(supabaseClientProvider).auth.signOut(),
          ),
        ],
      ),
    );
  }
}
