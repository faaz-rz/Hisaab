import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/hisaab_logo.dart';
import '../services/session_service.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Scaffold(
            appBar: AppBar(title: Text(SessionService.instance.current?.name ?? 'HISAAB'),
              actions: [IconButton(tooltip: 'Profiles', icon: const Icon(Icons.manage_accounts),
                  onPressed: () => context.push('/profiles'))]),
            body: child,
            bottomNavigationBar: _BottomNav(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _goToIndex(context, index),
            ),
          );
        }

        final collapsed = constraints.maxWidth < 900;
        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(
                context,
                selectedIndex: selectedIndex,
                collapsed: collapsed,
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context, {
    required int selectedIndex,
    required bool collapsed,
  }) {
    return Container(
      width: collapsed ? 72 : 220,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : 20,
              vertical: 28,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                HisaabLogo(size: collapsed ? 38 : 42),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'HISAAB',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          const SizedBox(height: 12),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isSelected: selectedIndex == 0,
            collapsed: collapsed,
            onTap: () => context.go('/'),
          ),
          _NavItem(
            icon: Icons.account_balance_rounded,
            label: 'Bank Ledger',
            isSelected: selectedIndex == 1,
            collapsed: collapsed,
            onTap: () => context.go('/ledger'),
          ),
          _NavItem(
            icon: Icons.swap_horiz_rounded,
            label: 'Transactions',
            isSelected: selectedIndex == 2,
            collapsed: collapsed,
            onTap: () => context.go('/transactions'),
          ),
          _NavItem(
            icon: Icons.receipt_long_rounded,
            label: 'Expenses',
            isSelected: selectedIndex == 3,
            collapsed: collapsed,
            onTap: () => context.go('/expenses'),
          ),
          _NavItem(
            icon: Icons.analytics_rounded,
            label: 'Reports',
            isSelected: selectedIndex == 4,
            collapsed: collapsed,
            onTap: () => context.go('/reports'),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.manage_accounts,
            label: SessionService.instance.current?.name ?? 'Profiles',
            isSelected: false,
            collapsed: collapsed,
            onTap: () => context.push('/profiles'),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          _NavItem(
            icon: Icons.cloud_sync_rounded,
            label: 'Backup & Sync',
            isSelected: false,
            collapsed: collapsed,
            onTap: () => context.push('/backup'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static void _goToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/ledger');
        break;
      case 2:
        context.go('/transactions');
        break;
      case 3:
        context.go('/expenses');
        break;
      case 4:
        context.go('/reports');
        break;
      case 5:
        context.push('/backup');
        break;
    }
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/ledger')) return 1;
    if (location.startsWith('/transactions')) return 2;
    if (location.startsWith('/expenses')) return 3;
    if (location.startsWith('/reports')) return 4;
    return 0;
  }
}

// ─── Sidebar Navigation Item ────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.collapsed = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 8 : 12,
        vertical: 2,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accent.withOpacity(0.2)
                : _isHovered
                    ? Colors.white.withOpacity(0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 16,
                  vertical: 12,
                ),
                child: widget.collapsed
                    ? Center(
                        child: Icon(
                          widget.icon,
                          size: 22,
                          color: widget.isSelected
                              ? AppColors.accentLight
                              : Colors.white.withOpacity(0.6),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            widget.icon,
                            size: 20,
                            color: widget.isSelected
                                ? AppColors.accentLight
                                : Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              widget.label,
                              style: GoogleFonts.inter(
                                color: widget.isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                fontWeight: widget.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (widget.isSelected)
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.collapsed) return content;
    return Tooltip(
      message: widget.label,
      child: content,
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _BottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_rounded),
          label: 'Ledger',
        ),
        NavigationDestination(
          icon: Icon(Icons.swap_horiz_rounded),
          label: 'Txns',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_rounded),
          label: 'Expenses',
        ),
        NavigationDestination(
          icon: Icon(Icons.analytics_rounded),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.cloud_sync_rounded),
          label: 'Backup',
        ),
      ],
    );
  }
}
