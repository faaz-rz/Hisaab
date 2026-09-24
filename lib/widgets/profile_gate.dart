import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../services/account_service.dart';
import '../services/session_service.dart';
import '../screens/profile_form.dart';

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
            // A fresh provider tree and router prevent any previous profile's
            // cached reports, unlocked sections or dialogs from surviving logout.
            return ProviderScope(
                key: ValueKey(session.current!.id), child: const PharmacyApp());
          }
          return MaterialApp(
            title: 'HISAAB',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                useMaterial3: true,
                colorScheme:
                    ColorScheme.fromSeed(seedColor: AppColors.primary)),
            home: FutureBuilder<void>(
                future: _loading,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Scaffold(
                        body: Center(
                            child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'HISAAB could not read your profile settings.\n'
                          'Your database files have not been changed. Contact support before resetting the app.'),
                    )));
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
  String? _selectedId;
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profiles = AccountService.instance.profiles;
      final profile = profiles
          .firstWhere((p) => p.id == (_selectedId ?? profiles.first.id));
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

  @override
  Widget build(BuildContext context) {
    final profiles = AccountService.instance.profiles;
    if (profiles.isEmpty) {
      return ProfileForm(
          firstProfile: true,
          onSaved: (_) {
            setState(() {});
          });
    }
    return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 420,
                child: Card(
                    child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.account_circle_outlined, size: 48),
                            const SizedBox(height: 16),
                            Text('HISAAB',
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            const Text('Choose your profile to continue.',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedId ?? profiles.first.id,
                              decoration:
                                  const InputDecoration(labelText: 'Profile'),
                              items: profiles
                                  .map((p) => DropdownMenuItem(
                                      value: p.id, child: Text(p.name)))
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                        _selectedId = value;
                                        _password.clear();
                                        _error = null;
                                      }),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                                controller: _password,
                                obscureText: true,
                                enabled: !_busy,
                                decoration: const InputDecoration(
                                    labelText: 'Password'),
                                onSubmitted: (_) => _login()),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 24),
                            FilledButton(
                                onPressed: _busy ? null : _login,
                                child: Text(
                                    _busy ? 'Opening profile…' : 'Sign in')),
                            const SizedBox(height: 12),
                            const Text(
                                'Each profile has its own records. Add another profile after signing in.',
                                textAlign: TextAlign.center),
                          ],
                        ))),
              )),
        ));
  }
}
