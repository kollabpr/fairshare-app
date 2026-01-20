import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import '../../config/app_animations.dart';
import 'dashboard_screen.dart';
import '../friends/friends_list_screen.dart';
import '../groups/group_list_screen.dart';
import '../profile/user_profile_screen.dart';

/// Main screen with bottom navigation
/// Modern Gen Z design with gradients and smooth animations
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _navAnimationController;

  // Tab screens
  final List<Widget> _screens = const [
    DashboardScreen(),
    FriendsListScreen(),
    GroupListScreenTab(),
    UserProfileScreen(),
  ];

  // Navigation items
  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.home_rounded,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Friends',
    ),
    _NavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Groups',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _navAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.standard,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);

    _pageController.animateToPage(
      index,
      duration: AppAnimations.standard,
      curve: AppAnimations.defaultCurve,
    );

    _navAnimationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              return _buildNavItem(index);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.defaultCurve,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentPrimary.withOpacity(0.2),
                      AppTheme.accentPrimary.withOpacity(0.05),
                    ],
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with glow effect when selected
              AnimatedContainer(
                duration: AppAnimations.fast,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow effect
                    if (isSelected)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentPrimary.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    // Icon
                    AnimatedSwitcher(
                      duration: AppAnimations.fast,
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        key: ValueKey('${index}_$isSelected'),
                        size: 26,
                        color: isSelected
                            ? AppTheme.accentPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Label
              AnimatedDefaultTextStyle(
                duration: AppAnimations.fast,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.accentPrimary
                      : AppTheme.textMuted,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation item data
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Group list screen adapted for tab navigation (no app bar title, etc.)
class GroupListScreenTab extends StatefulWidget {
  const GroupListScreenTab({super.key});

  @override
  State<GroupListScreenTab> createState() => _GroupListScreenTabState();
}

class _GroupListScreenTabState extends State<GroupListScreenTab> {
  @override
  Widget build(BuildContext context) {
    // Reuse the existing GroupListScreen but embedded in tab
    return const GroupListScreen();
  }
}
