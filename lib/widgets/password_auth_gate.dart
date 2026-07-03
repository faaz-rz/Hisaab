import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class PasswordAuthGate extends StatefulWidget {
  final String title;
  final String createMessage;
  final String verifyMessage;
  final IconData icon;
  final Future<bool> Function() isPasswordSet;
  final Future<void> Function(String password) setPassword;
  final Future<bool> Function(String password) verifyPassword;
  final VoidCallback onSuccess;
  final bool wrapInScaffold;
  final double width;

  const PasswordAuthGate({
    super.key,
    required this.title,
    required this.createMessage,
    required this.verifyMessage,
    required this.icon,
    required this.isPasswordSet,
    required this.setPassword,
    required this.verifyPassword,
    required this.onSuccess,
    this.wrapInScaffold = false,
    this.width = 400,
  });

  @override
  State<PasswordAuthGate> createState() => _PasswordAuthGateState();
}

class _PasswordAuthGateState extends State<PasswordAuthGate>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _focusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isCreatingPassword = false;
  bool _loading = true;
  String? _error;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _checkPasswordStatus();
  }

  Future<void> _checkPasswordStatus() async {
    final isSet = await widget.isPasswordSet();
    if (!mounted) return;
    setState(() {
      _isCreatingPassword = !isSet;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _focusNode.dispose();
    _confirmFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _error = message);
    _shakeController.forward(from: 0);
  }

  Future<void> _submit() async {
    if (_isCreatingPassword) {
      final pwd = _pinController.text.trim();
      final confirm = _confirmController.text.trim();
      if (pwd.isEmpty || pwd.length < 4) {
        _showError('Password must be at least 4 digits');
        return;
      }
      if (pwd != confirm) {
        _showError('Passwords do not match');
        _confirmController.clear();
        _confirmFocusNode.requestFocus();
        return;
      }
      await widget.setPassword(pwd);
      if (mounted) widget.onSuccess();
      return;
    }

    final isCorrect = await widget.verifyPassword(_pinController.text);
    if (!mounted) return;
    if (isCorrect) {
      widget.onSuccess();
    } else {
      _showError('Incorrect password. Try again.');
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final dx = _shakeAnimation.value *
                    10 *
                    ((_shakeController.value * 8).toInt().isEven ? 1 : -1);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Container(
                width: widget.width,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isCreatingPassword
                          ? widget.createMessage
                          : widget.verifyMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PasswordField(
                      controller: _pinController,
                      focusNode: _focusNode,
                      obscureText: _obscure,
                      labelText: _isCreatingPassword ? 'New Password' : null,
                      errorText: _error,
                      onVisibilityToggle: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmitted: () {
                        if (_isCreatingPassword) {
                          _confirmFocusNode.requestFocus();
                        } else {
                          _submit();
                        }
                      },
                    ),
                    if (_isCreatingPassword) ...[
                      const SizedBox(height: 16),
                      _PasswordField(
                        controller: _confirmController,
                        focusNode: _confirmFocusNode,
                        obscureText: _obscureConfirm,
                        labelText: 'Confirm Password',
                        onVisibilityToggle: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                        onSubmitted: _submit,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(
                          _isCreatingPassword
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isCreatingPassword ? 'Create Password' : 'Unlock',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    if (!widget.wrapInScaffold) return body;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: body,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final String? labelText;
  final String? errorText;
  final VoidCallback onVisibilityToggle;
  final VoidCallback onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.obscureText,
    required this.onVisibilityToggle,
    required this.onSubmitted,
    this.labelText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 6,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '- - - -',
        hintStyle: GoogleFonts.inter(
          fontSize: 18,
          letterSpacing: 6,
          color: AppColors.textSecondary.withOpacity(0.3),
        ),
        labelText: labelText,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: AppColors.surface,
        errorText: errorText,
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: onVisibilityToggle,
        ),
      ),
      onFieldSubmitted: (_) => onSubmitted(),
    );
  }
}

Future<void> showChangePasswordDialog(
  BuildContext context, {
  required String title,
  required String successMessage,
  required Future<bool> Function(String oldPassword, String newPassword)
      changePassword,
}) async {
  final oldPwdCtrl = TextEditingController();
  final newPwdCtrl = TextEditingController();
  final confirmPwdCtrl = TextEditingController();
  String? dialogError;
  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogPasswordField(
                  controller: oldPwdCtrl,
                  labelText: 'Current Password',
                  obscureText: obscureOld,
                  onVisibilityToggle: () =>
                      setDialogState(() => obscureOld = !obscureOld),
                ),
                const SizedBox(height: 16),
                _DialogPasswordField(
                  controller: newPwdCtrl,
                  labelText: 'New Password',
                  obscureText: obscureNew,
                  onVisibilityToggle: () =>
                      setDialogState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 16),
                _DialogPasswordField(
                  controller: confirmPwdCtrl,
                  labelText: 'Confirm New Password',
                  obscureText: obscureConfirm,
                  onVisibilityToggle: () =>
                      setDialogState(() => obscureConfirm = !obscureConfirm),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final oldPwd = oldPwdCtrl.text.trim();
                final newPwd = newPwdCtrl.text.trim();
                final confirmPwd = confirmPwdCtrl.text.trim();

                if (oldPwd.isEmpty) {
                  setDialogState(
                    () => dialogError = 'Enter your current password',
                  );
                  return;
                }
                if (newPwd.isEmpty || newPwd.length < 4) {
                  setDialogState(
                    () =>
                        dialogError = 'New password must be at least 4 digits',
                  );
                  return;
                }
                if (newPwd != confirmPwd) {
                  setDialogState(
                    () => dialogError = 'New passwords do not match',
                  );
                  return;
                }

                final success = await changePassword(oldPwd, newPwd);
                if (!ctx.mounted) return;
                if (success) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            successMessage,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                } else {
                  setDialogState(
                    () => dialogError = 'Current password is incorrect',
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Change Password'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  oldPwdCtrl.dispose();
  newPwdCtrl.dispose();
  confirmPwdCtrl.dispose();
}

class _DialogPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final VoidCallback onVisibilityToggle;

  const _DialogPasswordField({
    required this.controller,
    required this.labelText,
    required this.obscureText,
    required this.onVisibilityToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textSecondary,
          letterSpacing: 0,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: onVisibilityToggle,
        ),
      ),
    );
  }
}
