import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/sensor_service.dart';
import '../../theme/app_theme.dart';
import '../admin/user_management_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  final AuthService authService;
  final AppUser profile;

  const HomeShell({super.key, required this.authService, required this.profile});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _sensorService = SensorService(deviceId: 'device1');
  int _index = 0;

  List<_NavItem> get _items {
    final items = [
      const _NavItem('Live', Icons.dashboard_rounded),
      const _NavItem('History', Icons.show_chart_rounded),
      const _NavItem('Alerts', Icons.notifications_rounded),
      if (widget.profile.isAdmin)
        const _NavItem('Users', Icons.admin_panel_settings_rounded),
      const _NavItem('Profile', Icons.person_rounded),
    ];
    return items;
  }

  Widget _screenFor(int index) {
    final items = _items;
    final label = items[index].label;
    switch (label) {
      case 'Live':
        return DashboardScreen(service: _sensorService);
      case 'History':
        return HistoryScreen(service: _sensorService);
      case 'Alerts':
        return AlertsScreen(service: _sensorService);
      case 'Users':
        return UserManagementScreen(
          authService: widget.authService,
          currentAdminUid: widget.profile.uid,
        );
      case 'Profile':
        return ProfileScreen(authService: widget.authService, profile: widget.profile);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_index >= items.length) _index = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.compact;

        final body = Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.water_drop_rounded, color: AppColors.accent),
                const SizedBox(width: 10),
                Text(items[_index].label),
              ],
            ),
          ),
          body: SafeArea(child: _screenFor(_index)),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.accent.withValues(alpha: 0.2),
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: items
                      .map((e) => NavigationDestination(icon: Icon(e.icon), label: e.label))
                      .toList(),
                ),
        );

        if (!isWide) return body;

        // Tablet/desktop: side navigation rail instead of bottom nav.
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Row(
            children: [
              NavigationRail(
                backgroundColor: AppColors.surface,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                indicatorColor: AppColors.accent.withValues(alpha: 0.2),
                selectedIconTheme: const IconThemeData(color: AppColors.accent),
                unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
                selectedLabelTextStyle: const TextStyle(color: AppColors.accent),
                unselectedLabelTextStyle: const TextStyle(color: AppColors.textMuted),
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.water_drop_rounded,
                      color: AppColors.accent, size: 28),
                ),
                destinations: items
                    .map((e) => NavigationRailDestination(
                          icon: Icon(e.icon),
                          label: Text(e.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(
                child: Scaffold(
                  backgroundColor: AppColors.bg,
                  appBar: AppBar(title: Text(items[_index].label)),
                  body: SafeArea(child: _screenFor(_index)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
