import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../services/session_service.dart';

class ProfileForm extends StatefulWidget {
  final bool firstProfile;
  final LocalProfile? existing;
  final ValueChanged<LocalProfile> onSaved;
  const ProfileForm(
      {super.key,
      this.firstProfile = false,
      this.existing,
      required this.onSaved});
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _current = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final profile = existing == null
          ? await AccountService.instance.create(_name.text, _password.text)
          : await AccountService.instance.update(existing.id, _name.text,
              _current.text, _password.text.isEmpty ? null : _password.text);
      if (existing != null) SessionService.instance.updateCurrent(profile);
      if (mounted) widget.onSaved(profile);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is AccountException
            ? error.message
            : 'Could not save the profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
              title: Text(editing
                  ? 'Edit profile'
                  : widget.firstProfile
                      ? 'Set up your existing profile'
                      : 'Add profile')),
          body: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(widget.firstProfile
                            ? 'Choose a name and password for your existing HISAAB records. Your transactions, expenses and ledger will stay in this profile.'
                            : editing
                                ? 'Changing your name or password keeps all your records.'
                                : 'This profile starts with empty records and has all the same features. The other profile’s records stay separate.'),
                        const SizedBox(height: 24),
                        TextFormField(
                            controller: _name,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                                labelText: 'Profile name'),
                            maxLength: 60,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter a name'
                                    : null),
                        if (editing) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _current,
                              enabled: !_busy,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Current password'),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Enter your current password'
                                      : null),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: editing
                                    ? 'New password (optional)'
                                    : 'Password',
                                helperText: 'At least 8 characters'),
                            validator: (value) =>
                                editing && (value ?? '').isEmpty
                                    ? null
                                    : (value ?? '').length < 8
                                        ? 'Use at least 8 characters'
                                        : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: _confirm,
                            enabled: !_busy,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'Confirm password'),
                            validator: (value) => value != _password.text
                                ? 'Passwords do not match'
                                : null),
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
                            onPressed: _busy ? null : _save,
                            child: Text(_busy
                                ? 'Saving…'
                                : editing
                                    ? 'Save changes'
                                    : 'Create profile')),
                        const SizedBox(height: 16),
                        const Text(
                            'Keep your password somewhere safe. Password changes require the current password.'),
                      ])),
            ),
          )),
        ));
  }
}
