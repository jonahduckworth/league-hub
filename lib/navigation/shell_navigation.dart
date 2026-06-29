import 'package:flutter/material.dart';

enum ShellQuickDestination {
  contacts,
  policy,
  settings,
}

class ShellQuickDestinationConfig {
  final ShellQuickDestination destination;
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final double iconSize;

  const ShellQuickDestinationConfig({
    required this.destination,
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.iconSize,
  });
}

const Map<ShellQuickDestination, ShellQuickDestinationConfig>
    _quickDestinationConfigs = {
  ShellQuickDestination.contacts: ShellQuickDestinationConfig(
    destination: ShellQuickDestination.contacts,
    route: '/contacts',
    label: 'Contacts',
    icon: Icons.contacts_outlined,
    activeIcon: Icons.contacts_rounded,
    iconSize: 24,
  ),
  ShellQuickDestination.policy: ShellQuickDestinationConfig(
    destination: ShellQuickDestination.policy,
    route: '/policy',
    label: 'Policy',
    icon: Icons.folder_copy_outlined,
    activeIcon: Icons.folder_copy_rounded,
    iconSize: 24,
  ),
  ShellQuickDestination.settings: ShellQuickDestinationConfig(
    destination: ShellQuickDestination.settings,
    route: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    iconSize: 24,
  ),
};

bool shouldShowShellBottomNavigation(String location) {
  return !location.startsWith('/chat/');
}

ShellQuickDestinationConfig quickDestinationConfig(
  ShellQuickDestination destination,
) {
  return _quickDestinationConfigs[destination]!;
}

ShellQuickDestination? shellQuickDestinationForLocation(String location) {
  if (_matchesShellRoute(location, '/contacts')) {
    return ShellQuickDestination.contacts;
  }
  if (_matchesShellRoute(location, '/policy')) {
    return ShellQuickDestination.policy;
  }
  if (_matchesShellRoute(location, '/settings')) {
    return ShellQuickDestination.settings;
  }
  return null;
}

ShellQuickDestinationConfig? shellQuickDestinationConfigForLocation(
  String location,
) {
  final destination = shellQuickDestinationForLocation(location);
  return destination == null ? null : quickDestinationConfig(destination);
}

int shellBottomNavIndexFor({
  required int branchIndex,
  required String location,
}) {
  if (shellQuickDestinationForLocation(location) != null) {
    return 3;
  }

  return switch (branchIndex) {
    3 => 1,
    1 => 2,
    5 => 3,
    _ => 0,
  };
}

int shellBranchNavSlot(int branchIndex) {
  return switch (branchIndex) {
    0 => 0,
    3 => 1,
    1 => 2,
    2 || 4 || 5 || 6 => 3,
    _ => 0,
  };
}

bool _matchesShellRoute(String location, String route) {
  return location == route || location.startsWith('$route/');
}
