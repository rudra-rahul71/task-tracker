import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';

class NavigatorScafold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const NavigatorScafold({super.key, required this.navigationShell});

  @override
  State<NavigatorScafold> createState() => _NavigatorScafoldState();
}

class _NavigatorScafoldState extends State<NavigatorScafold> {
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToForegroundMessages();
  }

  void _subscribeToForegroundMessages() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<RemoteNotificationService>()) {
      final remoteNotificationService = getIt<RemoteNotificationService>();
      _foregroundMessageSubscription =
          remoteNotificationService.onForegroundMessage.listen((message) {
        if (!mounted) return;
        final notificationTitle =
            message.notification?.title ?? 'Notification';
        final notificationBody = message.notification?.body;
        AppBannerService.showInfo(
          context,
          title: notificationTitle,
          body: notificationBody,
          data: message.data,
        );
      });
    }
  }

  @override
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }

  void _navigate(int index, BuildContext context) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  static const _destinations = [
    _Destination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _Destination(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Tasks',
    ),
    _Destination(
      icon: Icons.track_changes_outlined,
      selectedIcon: Icons.track_changes,
      label: 'Trackers',
    ),
    _Destination(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
      label: 'Account',
    ),
  ];

  Widget _buildBottomIsland(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final islandWidth = width < 600 ? double.infinity : 480.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      heightFactor: 1.0,
      child: Container(
        width: islandWidth,
        margin: EdgeInsets.only(
          left: width < 600 ? 16.0 : 0.0,
          right: width < 600 ? 16.0 : 0.0,
          bottom: 24.0,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              final isSelected = widget.navigationShell.currentIndex == index;

              return InkWell(
                onTap: () => _navigate(index, context),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? destination.selectedIcon
                            : destination.icon,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          destination.label,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: widget.navigationShell),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomIsland(context),
      ),
    );
  }
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
