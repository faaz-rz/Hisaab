import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/hisaab_logo.dart';
import '../widgets/profile_avatar.dart';
import '../services/session_service.dart';

const _destinations = [
  (path: '/', label: 'Dashboard', icon: Icons.grid_view_rounded),
  (path: '/ledger', label: 'Bank Ledger', icon: Icons.account_balance_outlined),
  (
    path: '/transactions',
    label: 'Transactions',
    icon: Icons.swap_horiz_rounded
  ),
  (path: '/expenses', label: 'Expenses', icon: Icons.receipt_long_outlined),
  (path: '/reports', label: 'Reports', icon: Icons.bar_chart_rounded),
];

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _destinations.indexWhere((item) => item.path == location);
    final index = selected < 0 ? 0 : selected;
    final profile = SessionService.instance.current;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 700;
      if (compact) {
        return Scaffold(
          appBar: AppBar(
              toolbarHeight: 58,
              titleSpacing: 16,
              title: Row(children: [
                const HisaabLogo(size: 30),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(profile?.name ?? 'HISAAB',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600)))
              ]),
              actions: [
                IconButton(
                    tooltip: 'Backup & Sync',
                    onPressed: () => context.push('/backup'),
                    icon: const Icon(Icons.cloud_sync_outlined)),
                IconButton(
                    tooltip: 'Profiles',
                    onPressed: () => context.push('/profiles'),
                    icon: const Icon(Icons.manage_accounts_outlined))
              ]),
          body: child,
          bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (value) =>
                  context.go(_destinations[value].path),
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                      icon: Icon(item.icon), label: item.label)
              ]),
        );
      }
      final collapsed = constraints.maxWidth < 1100;
      return Scaffold(
          body: Row(children: [
        _sidebar(context, index, collapsed),
        Expanded(
            child: Column(children: [
          SizedBox(
              height: 62,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(children: [
                    Text('Workspace',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.chevron_right,
                            size: 14, color: AppColors.textSecondary)),
                    Expanded(
                        child: Text(_destinations[index].label,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600))),
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppColors.accent, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('On this computer',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]))),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.divider)),
                      child: child))),
        ])),
      ]));
    });
  }

  Widget _sidebar(BuildContext context, int selected, bool collapsed) {
    final profile = SessionService.instance.current;
    return Container(
      width: collapsed ? 84 : 240,
      color: AppColors.primary,
      child: SafeArea(
          child: Column(children: [
        Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 20 : 24, 28, 20, 28),
            child: Row(children: [
              const HisaabLogo(size: 42),
              if (!collapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('HISAAB',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8)),
                      const SizedBox(height: 4),
                      Text('Your everyday accounts',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: Colors.white60)),
                    ])),
              ]
            ])),
        Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
          if (!collapsed)
            Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 20, 16),
                child: Text('WORKSPACE',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.7,
                        color: Colors.white54))),
          for (var i = 0; i < _destinations.length; i++)
            _NavItem(
                icon: _destinations[i].icon,
                label: _destinations[i].label,
                selected: selected == i,
                collapsed: collapsed,
                onTap: () => context.go(_destinations[i].path)),
          const SizedBox(height: 28),
          if (!collapsed)
            Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 20, 16),
                child: Text('MANAGE',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.7,
                        color: Colors.white54))),
          _NavItem(
              icon: Icons.cloud_sync_outlined,
              label: 'Backup & Sync',
              collapsed: collapsed,
              onTap: () => context.push('/backup')),
        ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Colors.white.withValues(alpha: .12))),
        if (profile != null)
          Padding(
              padding: EdgeInsets.all(collapsed ? 14 : 20),
              child: Tooltip(
                  message: 'Manage ${profile.name}',
                  child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/profiles'),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              ProfileAvatar(profile: profile, size: 38),
                              if (!collapsed) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(profile.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 5),
                                      Text('Manage profile',
                                          style: GoogleFonts.inter(
                                              color: Colors.white60,
                                              fontSize: 11)),
                                    ])),
                                const Icon(Icons.unfold_more_rounded,
                                    color: Colors.white54, size: 17)
                              ],
                            ])),
                      )))),
      ])),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.selected = false,
      required this.collapsed});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Tooltip(
            message: collapsed ? label : '',
            child: Semantics(
                selected: selected,
                button: true,
                child: Material(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      hoverColor: Colors.white.withValues(alpha: .08),
                      focusColor: Colors.white.withValues(alpha: .12),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          child: Row(
                              mainAxisAlignment: collapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(icon,
                                    size: 21,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70),
                                if (!collapsed) ...[
                                  const SizedBox(width: 13),
                                  Expanded(
                                      child: Text(label,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.white70)))
                                ],
                              ])),
                    )))),
      );
}
