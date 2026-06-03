import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigatorScafold extends StatefulWidget {
  final Widget child;
  final String? location;

  const NavigatorScafold({super.key, required this.child, this.location});

  @override
  State<NavigatorScafold> createState() => _NavigatorScafoldState();
}

class _NavigatorScafoldState extends State<NavigatorScafold>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool extendRail = false;

  int _getSelectedIndexForLocation(String? location) {
    if (location == null) return 0;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/trackers')) return 2;
    if (location.startsWith('/account')) return 3;
    return 0;
  }

  late final AnimationController _overlayController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _getSelectedIndexForLocation(widget.location);
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didUpdateWidget(NavigatorScafold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location) {
      setState(() {
        _selectedIndex = _getSelectedIndexForLocation(widget.location);
      });
    }
  }
  late final Animation<Offset> _slideAnimation =
      Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _overlayController, curve: Curves.easeOutCubic),
      );
  late final Animation<double> _scrimAnimation = CurvedAnimation(
    parent: _overlayController,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  void _toggleRail() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    setState(() {
      extendRail = !extendRail;
    });

    if (isSmallScreen) {
      if (extendRail) {
        _overlayController.forward();
      } else {
        _overlayController.reverse();
      }
    }
  }

  void _collapseOverlay() {
    setState(() {
      extendRail = false;
    });
    _overlayController.reverse();
  }

  void _navigate(int index, BuildContext context) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/tasks');
        break;
      case 2:
        context.go('/trackers');
        break;
      case 3:
        context.go('/account');
        break;
    }
  }

  static const _destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist),
      label: Text('Tasks'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.track_changes_outlined),
      selectedIcon: Icon(Icons.track_changes),
      label: Text('Trackers'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.account_circle_outlined),
      selectedIcon: Icon(Icons.account_circle),
      label: Text('Account'),
    ),
  ];

  Widget _buildRail(
    BuildContext context, {
    required bool extended,
    bool autoCollapse = false,
  }) {
    return NavigationRail(
      extended: extended,
      minWidth: 60,
      minExtendedWidth: 180,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      selectedIndex: _selectedIndex,
      groupAlignment: -1.0,
      destinations: _destinations,
      selectedIconTheme: IconThemeData(
        color: Theme.of(context).colorScheme.primary,
      ),
      selectedLabelTextStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Align(
          alignment: extended ? Alignment.centerLeft : Alignment.center,
          child: InkWell(
            onTap: _toggleRail,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? 12.0 : 8.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu, color: Colors.grey),
                  if (extended) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'Task Tracker',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      onDestinationSelected: (int index) {
        if (autoCollapse && extendRail) {
          _collapseOverlay();
        }
        _navigate(index, context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Base layer: collapsed/expanded rail + page content
            Row(
              children: <Widget>[
                if (isSmallScreen)
                  _buildRail(context, extended: false)
                else
                  _buildRail(context, extended: extendRail),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: widget.child),
              ],
            ),
            // Overlay layer: animated scrim + sliding rail (small screens only)
            if (isSmallScreen) ...[
              // Scrim fades in/out
               IgnorePointer(
                ignoring: !extendRail,
                child: FadeTransition(
                  opacity: _scrimAnimation,
                  child: GestureDetector(
                    onTap: _collapseOverlay,
                    child: Container(color: Colors.black54),
                  ),
                ),
              ),
              // Rail slides in from the left
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Material(
                    elevation: 16,
                    child: _buildRail(
                      context,
                      extended: true,
                      autoCollapse: true,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
