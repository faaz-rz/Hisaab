import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../services/profile_photo.dart';
import '../services/session_service.dart';
import '../widgets/profile_avatar.dart';

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
  late bool _protected = widget.existing?.passwordRequired ?? false;
  late String? _photo = widget.existing?.photoBase64;
  bool _busy = false;
  bool _visible = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
          dialogTitle: 'Choose a profile photo');
      final path = result?.files.single.path;
      if (path == null) return;
      final file = File(path);
      if (await file.length() > 5 * 1024 * 1024) {
        throw const AccountException('Choose a photo smaller than 5 MB.');
      }
      final photo = await prepareProfilePhoto(await file.readAsBytes());
      if (mounted) setState(() => _photo = photo);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is AccountException
            ? error.message
            : 'Choose a valid PNG, JPEG or WebP photo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          ? await AccountService.instance.create(_name.text, _password.text,
              passwordRequired: _protected, photoBase64: _photo)
          : await AccountService.instance.update(existing.id, _name.text,
              _current.text, _password.text.isEmpty ? null : _password.text,
              passwordRequired: _protected,
              photoBase64: _photo,
              removePhoto: _photo == null);
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
    final keepingPassword = editing && widget.existing!.passwordRequired;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: const Color(0xFFF2F5F8),
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
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                                child: ProfileAvatar(
                                    size: 88,
                                    profile: LocalProfile(
                                        id: widget.existing?.id ?? 'primary',
                                        name: _name.text,
                                        photoBase64: _photo))),
                            const SizedBox(height: 12),
                            Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                      onPressed: _busy ? null : _pickPhoto,
                                      icon: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 18),
                                      label: Text(_photo == null
                                          ? 'Add photo (optional)'
                                          : 'Change photo')),
                                  if (_photo != null)
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () =>
                                                setState(() => _photo = null),
                                        child: const Text('Remove photo')),
                                ]),
                            const SizedBox(height: 16),
                            Text(
                                widget.firstProfile
                                    ? 'Make yourself at home'
                                    : editing
                                        ? 'Your profile, your way'
                                        : 'A space of your own',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(widget.firstProfile
                                ? 'Your transactions and expenses stay with this first profile. Your existing bank ledger becomes shared with all profiles.'
                                : editing
                                    ? 'Names, photos and password choices can change. Your records stay safe.'
                                    : 'Start with separate sales, purchases and expenses. The bank ledger is shared with all profiles.'),
                            const SizedBox(height: 24),
                            TextFormField(
                                controller: _name,
                                enabled: !_busy,
                                maxLength: 60,
                                onChanged: (_) => setState(() {}),
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                    labelText: 'Profile name',
                                    prefixIcon: Icon(Icons.person_outline)),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Enter a name'
                                        : null),
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Require a password'),
                                subtitle: Text(_protected
                                    ? 'Use a password or a PIN of 4 or more characters.'
                                    : 'Anyone using this computer can open this profile.'),
                                value: _protected,
                                onChanged: _busy
                                    ? null
                                    : (value) =>
                                        setState(() => _protected = value)),
                            if (keepingPassword) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _current,
                                  enabled: !_busy,
                                  obscureText: !_visible,
                                  decoration: const InputDecoration(
                                      labelText: 'Current password',
                                      helperText:
                                          'Required to change or remove existing protection.'),
                                  validator: (value) => (value ?? '').isEmpty
                                      ? 'Enter your current password'
                                      : null),
                            ],
                            AnimatedSize(
                                duration: duration,
                                alignment: Alignment.topCenter,
                                child: !_protected
                                    ? const SizedBox(width: double.infinity)
                                    : Column(children: [
                                        const SizedBox(height: 16),
                                        TextFormField(
                                            controller: _password,
                                            enabled: !_busy,
                                            obscureText: !_visible,
                                            decoration: InputDecoration(
                                                labelText: keepingPassword
                                                    ? 'New password (optional)'
                                                    : 'Password or PIN',
                                                helperText: keepingPassword
                                                    ? 'Leave blank to keep your current password.'
                                                    : 'Minimum 4 characters; for example, a 4-digit PIN.',
                                                suffixIcon: IconButton(
                                                    tooltip: _visible
                                                        ? 'Hide password'
                                                        : 'Show password',
                                                    onPressed: () => setState(
                                                        () =>
                                                            _visible =
                                                                !_visible),
                                                    icon: Icon(_visible
                                                        ? Icons
                                                            .visibility_off_outlined
                                                        : Icons
                                                            .visibility_outlined))),
                                            validator: (value) => keepingPassword &&
                                                    (value ?? '').isEmpty
                                                ? null
                                                : (value ?? '').length < 4
                                                    ? 'Use at least 4 characters'
                                                    : null),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                            controller: _confirm,
                                            enabled: !_busy,
                                            obscureText: !_visible,
                                            decoration: const InputDecoration(
                                                labelText: 'Confirm password'),
                                            validator: (value) =>
                                                value != _password.text
                                                    ? 'Passwords do not match'
                                                    : null),
                                      ])),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 24),
                            FilledButton(
                                onPressed: _busy ? null : _save,
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(50)),
                                child: Text(_busy
                                    ? 'Saving…'
                                    : editing
                                        ? 'Save changes'
                                        : 'Create profile')),
                            const SizedBox(height: 16),
                            const Text(
                                'Saved only on this computer. Keep any password safe; there is no email-based recovery.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF637383))),
                          ])),
                ),
              ),
            ),
          )),
        ));
  }
}
