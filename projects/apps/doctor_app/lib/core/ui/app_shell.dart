import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Scaffold used by the four primary destinations.
///
/// Phones use a bottom navigation bar; tablets and desktop windows use a
/// navigation rail so the content is not squeezed.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final int currentIndex;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  static const _destinations = [
    _Destination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: AppRoutes.dashboard,
    ),
    _Destination(
      label: 'Notes',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      route: AppRoutes.notes,
    ),
    _Destination(
      label: 'Search',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      route: AppRoutes.search,
    ),
    _Destination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      route: AppRoutes.settings,
    ),
  ];

  void _select(BuildContext context, int index) {
    if (index == currentIndex) return;
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final appBar = AppBar(title: Text(title), actions: actions);

        if (!wide) {
          return Scaffold(
            appBar: appBar,
            body: SafeArea(child: child),
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _select(context, index),
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) => _select(context, index),
                  labelType: constraints.maxWidth >= 1200
                      ? NavigationRailLabelType.all
                      : NavigationRailLabelType.selected,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 12),
                    child: Icon(Icons.medical_information_outlined, size: 28),
                  ),
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
