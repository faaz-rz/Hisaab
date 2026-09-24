import 'package:flutter/material.dart';
import '../widgets/workspace_components.dart';
import '../services/account_service.dart';
import '../services/session_service.dart';
import 'profile_form.dart';
import '../widgets/profile_avatar.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});
  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  Future<void> _showForm({LocalProfile? existing}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => ProfileForm(
            existing: existing, onSaved: (_) => Navigator.pop(context))));
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    try {
      await SessionService.instance.signOut();
    } on AccountException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = SessionService.instance.current;
    return Scaffold(
      appBar: AppBar(
          title: const PageHeading(
              title: 'Profiles',
              subtitle:
                  'Your businesses, each with their own private records')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Signed in as ${current?.name ?? ''}',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Sales, purchases and expenses are separate. The bank ledger, bank accounts and ledger password are shared. Each profile chooses its own photo and optional login password.'),
        const SizedBox(height: 16),
        for (final profile in AccountService.instance.profiles)
          ListTile(
              leading: ProfileAvatar(profile: profile, size: 44),
              title: Text(profile.name),
              subtitle: Text(profile.id == current?.id
                  ? 'Current profile · ${profile.passwordRequired ? 'Password protected' : 'No login password'}'
                  : '${profile.passwordRequired ? 'Password protected' : 'No login password'} · Switch profile to open'),
              trailing: profile.id == current?.id
                  ? TextButton(
                      onPressed: () => _showForm(existing: profile),
                      child: const Text('Edit'))
                  : null),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: () => _showForm(),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add profile')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out / Switch profile')),
      ]),
    );
  }
}
