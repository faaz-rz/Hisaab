import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/hisaab_logo.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          // ─── Sidebar ──────────────────────────────
          Container(
            width: 220,
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
                // ─── App Logo / Branding ───
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Row(
                    children: [
                      const HisaabLogo(size: 42),
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
                  ),
                ),

                Divider(color: Colors.white.withOpacity(0.1), height: 1),
                const SizedBox(height: 12),

                // ─── Navigation Items ───
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => context.go('/'),
                ),
                _NavItem(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank Ledger',
                  isSelected: selectedIndex == 1,
                  onTap: () => context.go('/ledger'),
                ),
                _NavItem(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transactions',
                  isSelected: selectedIndex == 2,
                  onTap: () => context.go('/transactions'),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Expenses',
                  isSelected: selectedIndex == 3,
                  onTap: () => context.go('/expenses'),
                ),
                _NavItem(
                  icon: Icons.analytics_rounded,
                  label: 'Reports',
                  isSelected: selectedIndex == 4,
                  onTap: () => context.go('/reports'),
                ),

                const Spacer(),

                // ─── Footer: Backup ───
                Divider(color: Colors.white.withOpacity(0.1), height: 1),
                _NavItem(
                  icon: Icons.cloud_sync_rounded,
                  label: 'Backup & Sync',
                  isSelected: false,
                  onTap: () => context.push('/backup'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ─── Main Content ─────────────────────────
          Expanded(child: child),
        ],
      ),
    );
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
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
  }
}
