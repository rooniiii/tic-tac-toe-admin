import 'package:flutter/material.dart';

class AdminDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;
  final bool isSidebar;

  const AdminDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    this.isSidebar = false,
  });

  static const Color background = Color(0xFF0B0B2B);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF2BD6);
  static const Color yellow = Color(0xFFFFD600);
  static const Color cardColor = Color(0xFF171F35);

  static const List<_MenuItem> _menuItems = [
    _MenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
    ),
    _MenuItem(
      title: 'Registered Users',
      icon: Icons.people_alt_rounded,
    ),
    _MenuItem(
      title: 'Player Profiles',
      icon: Icons.account_circle_rounded,
    ),
    _MenuItem(
      title: 'Statistics',
      icon: Icons.analytics_rounded,
    ),
    _MenuItem(
      title: 'Game History',
      icon: Icons.sports_esports_rounded,
    ),
    _MenuItem(
      title: 'Manage Admins',
      icon: Icons.admin_panel_settings_rounded,
    ),
  ];

  Widget _buildContent() {
    return Container(
      color: background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [purple, pink],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEON XO',
                          style: TextStyle(
                            color: cyan,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'ADMIN PANEL',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Material(
                      color: isSelected
                          ? purple.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onItemSelected(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                              color: cyan.withValues(alpha: 0.55),
                            )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: isSelected
                                    ? cyan
                                    : Colors.white60,
                                size: 21,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: cyan,
                                  size: 13,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Divider(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.redAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onLogout,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                              size: 21,
                            ),
                            SizedBox(width: 13),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'NEON XO Admin • v1.0',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSidebar) {
      return SizedBox(
        width: 260,
        child: Material(
          color: background,
          elevation: 8,
          child: _buildContent(),
        ),
      );
    }

    return Drawer(
      backgroundColor: background,
      width: 290,
      child: _buildContent(),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;

  const _MenuItem({
    required this.title,
    required this.icon,
  });
}
