import 'package:flutter/material.dart';
import '../theme/neo_theme.dart';

class NeoNavItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final bool isDestructive;

  const NeoNavItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
    this.isDestructive = false,
  });
}

class NeoBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLogoutTap;

  const NeoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onLogoutTap,
  });

  static const List<NeoNavItem> items = [
    NeoNavItem(title: 'BERANDA', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
    NeoNavItem(title: 'UJIAN', icon: Icons.assignment_outlined, activeIcon: Icons.assignment),
    NeoNavItem(title: 'PROFIL', icon: Icons.person_outline, activeIcon: Icons.person),
    NeoNavItem(title: 'SARAN', icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble),
    NeoNavItem(title: 'LOGOUT', icon: Icons.logout, activeIcon: Icons.logout, isDestructive: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NeoColors.surface,
        border: Border(
          top: BorderSide(color: NeoColors.ink, width: 3),
        ),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4
            : 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = currentIndex == index && !item.isDestructive;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (item.isDestructive) {
                  onLogoutTap();
                } else {
                  onTap(index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? NeoColors.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: NeoColors.ink, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: NeoColors.ink,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 22,
                      color: item.isDestructive
                          ? NeoColors.danger
                          : NeoColors.ink,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: item.isDestructive
                            ? NeoColors.danger
                            : NeoColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
