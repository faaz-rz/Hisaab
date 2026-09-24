import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/account_service.dart';
import '../services/session_service.dart';
import '../screens/profile_form.dart';
import 'profile_avatar.dart';
import 'hisaab_logo.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final Future<void> _loading = AccountService.instance.load();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SessionService.instance,
        builder: (context, _) {
          final session = SessionService.instance;
          if (session.current != null && !session.busy) {
            // Dispose immediately on logout: no outgoing animation may retain the
            // previous profile's private widgets, router or provider caches.
            return ProviderScope(
                key: ValueKey(session.current!.id), child: const PharmacyApp());
          }
          return MaterialApp(
            title: 'HISAAB',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                textTheme: GoogleFonts.interTextTheme(),
                colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
                inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: const Color(0xFFF2F5F8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none)),
                pageTransitionsTheme: const PageTransitionsTheme(builders: {
                  TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
                  TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                })),
            home: FutureBuilder<void>(
                future: _loading,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Scaffold(
                        body: Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'HISAAB could not read your profile settings.\nYour database files have not been changed. Contact support before resetting the app.'))));
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  return const _LoginScreen();
                }),
          );
        },
      );
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _password = TextEditingController();
  LocalProfile? _selected;
  String? _error;
  bool _busy = false;
  bool _visible = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(LocalProfile profile) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _selected = profile;
    });
    try {
      await SessionService.instance.signIn(profile, _password.text);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is AccountException
            ? error.message
            : 'Could not open this profile. Your records are still on this computer. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose(LocalProfile profile) {
    if (_busy) return;
    _password.clear();
    setState(() {
      _selected = profile;
      _error = null;
      _visible = false;
    });
    if (!profile.passwordRequired) _login(profile);
  }

  void _back() {
    if (_busy) return;
    _password.clear();
    setState(() {
      _selected = null;
      _error = null;
      _visible = false;
    });
  }

  Future<void> _addProfile() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) =>
            ProfileForm(onSaved: (_) => Navigator.pop(routeContext))));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profiles = AccountService.instance.profiles;
    if (profiles.isEmpty) {
      return ProfileForm(firstProfile: true, onSaved: (_) => setState(() {}));
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reducedMotion ? Duration.zero : const Duration(milliseconds: 240);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selected != null) _back();
        },
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                  Color(0xFF0C192A),
                  Color(0xFF142D3B),
                  Color(0xFF10202E)
                ])),
            child: SafeArea(
                child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth < 500 ? 20 : 48,
                      vertical: 36),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HisaabLogo(size: 44),
                              SizedBox(width: 12),
                              Text('HISAAB',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      letterSpacing: 5,
                                      fontWeight: FontWeight.w700)),
                            ]),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: AnimatedSwitcher(
                              duration: duration,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (current, previous) =>
                                  Stack(alignment: Alignment.center, children: [
                                for (final child in previous)
                                  ExcludeSemantics(
                                      child: IgnorePointer(child: child)),
                                if (current != null) current,
                              ]),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                          position: Tween<Offset>(
                                                  begin: const Offset(0, .025),
                                                  end: Offset.zero)
                                              .animate(animation),
                                          child: child)),
                              child: _selected == null
                                  ? _picker(profiles, constraints.maxWidth)
                                  : _passwordPanel(_selected!),
                            )),
                        const Column(children: [
                          Text('Separate businesses. One shared bank ledger.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFFBFCDD8), fontSize: 13)),
                          SizedBox(height: 8),
                          Text('PRIVATE & LOCAL  •  MADE FOR YOUR EVERYDAY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF8198AA),
                                  fontSize: 10,
                                  letterSpacing: 1.5)),
                        ]),
                      ]),
                ),
              )),
            )),
          ),
        ));
  }

  Widget _picker(List<LocalProfile> profiles, double width) => Column(
          key: const ValueKey('picker'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Who’s keeping the books?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: width < 500 ? 28 : 40,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.8)),
            const SizedBox(height: 14),
            const Text('Choose a profile to pick up where you left off.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB2C4D2), fontSize: 16)),
            const SizedBox(height: 40),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 24,
                  children: [
                    for (final profile in profiles)
                      _ProfileTile(
                          profile: profile, onTap: () => _choose(profile))
                  ],
                )),
            const SizedBox(height: 32),
            OutlinedButton.icon(
                onPressed: _addProfile,
                icon: const Icon(Icons.add, size: 18),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCEE1E8),
                    side: const BorderSide(color: Color(0xFF49616F)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18)),
                label: const Text('Add profile')),
          ]);

  Widget _passwordPanel(LocalProfile profile) => SizedBox(
      key: ValueKey(profile.id),
      width: 420,
      child: Card(
        color: const Color(0xFFFCFDFE),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('All profiles'))),
              const SizedBox(height: 12),
              ProfileAvatar(profile: profile, size: 88),
              const SizedBox(height: 20),
              Text(profile.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15283A))),
              const SizedBox(height: 8),
              Text(
                  profile.passwordRequired
                      ? 'Welcome back. Enter your password or PIN.'
                      : 'Your workspace is ready.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF657789))),
              const SizedBox(height: 24),
              if (profile.passwordRequired)
                TextField(
                    key: const ValueKey('login-password'),
                    controller: _password,
                    autofocus: true,
                    obscureText: !_visible,
                    enabled: !_busy,
                    onSubmitted: (_) => _login(profile),
                    decoration: InputDecoration(
                        labelText: 'Password or PIN',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                            tooltip:
                                _visible ? 'Hide password' : 'Show password',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _visible = !_visible),
                            icon: Icon(_visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined)))),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(_error!,
                            style: const TextStyle(color: Color(0xFFB3261E))))),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: _busy ? null : () => _login(profile),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                      child: _busy
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  SizedBox(width: 12),
                                  Text('Opening profile…'),
                                ])
                          : Text(profile.passwordRequired
                              ? 'Sign in'
                              : 'Open profile'))),
            ])),
      ));
}

class _ProfileTile extends StatefulWidget {
  final LocalProfile profile;
  final VoidCallback onTap;
  const _ProfileTile({required this.profile, required this.onTap});
  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _focused;
    return Semantics(
        button: true,
        label: 'Open ${widget.profile.name}',
        child: SizedBox(
          width: 170,
          child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHover: (value) => setState(() => _hovered = value),
                onFocusChange: (value) => setState(() => _focused = value),
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  decoration: BoxDecoration(
                      color: highlighted
                          ? Colors.white.withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: highlighted
                              ? const Color(0xFF8CE3D0)
                              : Colors.transparent,
                          width: 2)),
                  child: Column(children: [
                    ProfileAvatar(profile: widget.profile, size: 116),
                    const SizedBox(height: 18),
                    Text(widget.profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(
                          widget.profile.passwordRequired
                              ? Icons.lock_outline
                              : Icons.touch_app_outlined,
                          size: 13,
                          color: const Color(0xFF97B0C1)),
                      const SizedBox(width: 5),
                      Flexible(
                          child: Text(
                              widget.profile.passwordRequired
                                  ? 'Password protected'
                                  : 'Tap to open',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFFACC2D1)))),
                    ]),
                  ]),
                ),
              )),
        ));
  }
}
