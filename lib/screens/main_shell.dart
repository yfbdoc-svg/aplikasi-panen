import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'input_menu_screen.dart';
import 'more_menu_screen.dart';
import 'rekap_menu_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int dashboardRefreshToken = 0;
  int rekapRefreshToken = 0;

  void _changeTab(int value) {
    setState(() {
      index = value;
      if (value == 0) dashboardRefreshToken++;
      if (value == 2) rekapRefreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(refreshToken: dashboardRefreshToken),
      const InputMenuScreen(),
      RekapMenuScreen(refreshToken: rekapRefreshToken),
      const MoreMenuScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: _BottomNav(index: index, onChanged: _changeTab),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomNav({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0D7A3A);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 350;
    final compact = width < 390;
    final navHeight = narrow ? 62.0 : (compact ? 66.0 : 70.0);
    final iconSize = narrow ? 20.0 : (compact ? 22.0 : 24.0);
    final textSize = narrow ? 8.8 : (compact ? 9.5 : 10.5);

    const items = <_NavItem>[
      _NavItem(Icons.home_rounded, 'Dashboard'),
      _NavItem(Icons.assignment_rounded, 'Operasional'),
      _NavItem(Icons.bar_chart_rounded, 'Rekap'),
      _NavItem(Icons.more_horiz_rounded, 'Lainnya'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: navHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFDDE5DE), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final item = items[i];
            final active = i == index;

            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: SizedBox(
                  height: navHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: iconSize,
                        color: active ? green : const Color(0xFF7B8796),
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              color: active ? green : const Color(0xFF7B8796),
                              fontSize: textSize,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: active ? 26 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: active ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}
