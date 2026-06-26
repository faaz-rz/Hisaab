import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ledger_provider.dart';
import '../models/bank_ledger.dart';
import '../widgets/add_ledger_dialog.dart';
import '../services/pdf_service.dart';
import '../services/password_service.dart';
import '../widgets/month_year_picker.dart';
import '../main.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  bool _authenticated = false;

  void _onAuthenticated() {
    setState(() => _authenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return _LedgerAuthScreen(onSuccess: _onAuthenticated);
    }
    return const _LedgerDashboard();
  }
}

// ════════════════════════════════════════════════════════════════
// ─── AUTH SCREEN (handles both create & verify) ───────────────
// ════════════════════════════════════════════════════════════════
class _LedgerAuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const _LedgerAuthScreen({required this.onSuccess});

  @override
  State<_LedgerAuthScreen> createState() => _LedgerAuthScreenState();
}

class _LedgerAuthScreenState extends State<_LedgerAuthScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _focusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _isCreatingPassword = false;
  bool _loading = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    final isSet = await PasswordService.instance.isLedgerPasswordSet();
    setState(() {
      _isCreatingPassword = !isSet;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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

  void _submit() async {
    if (_isCreatingPassword) {
      // ── Creating a new password ──
      final pwd = _pinController.text.trim();
      final confirm = _confirmController.text.trim();
      if (pwd.isEmpty || pwd.length < 4) {
        setState(() => _error = 'Password must be at least 4 digits');
        _shakeController.forward(from: 0);
        return;
      }
      if (pwd != confirm) {
        setState(() => _error = 'Passwords do not match');
        _shakeController.forward(from: 0);
        _confirmController.clear();
        _confirmFocusNode.requestFocus();
        return;
      }
      await PasswordService.instance.setLedgerPassword(pwd);
      widget.onSuccess();
    } else {
      // ── Verifying existing password ──
      final isCorrect = await PasswordService.instance
          .verifyLedgerPassword(_pinController.text);
      if (isCorrect) {
        widget.onSuccess();
      } else {
        setState(() => _error = 'Incorrect password. Try again.');
        _shakeController.forward(from: 0);
        _pinController.clear();
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final dx = _shakeAnimation.value *
                10 *
                ((_shakeController.value * 8).toInt().isEven ? 1 : -1);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Shield icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isCreatingPassword
                        ? Icons.lock_rounded
                        : Icons.shield_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bank Ledger',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isCreatingPassword
                      ? 'Create a password to protect your financial data'
                      : 'Enter password to access sensitive financial data',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Password field
                TextFormField(
                  controller: _pinController,
                  focusNode: _focusNode,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '• • • • • • • •',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 18,
                      letterSpacing: 6,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    labelText: _isCreatingPassword ? 'New Password' : null,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      letterSpacing: 0,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _error != null
                            ? AppColors.danger.withOpacity(0.5)
                            : AppColors.divider,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (_isCreatingPassword) {
                      _confirmFocusNode.requestFocus();
                    } else {
                      _submit();
                    }
                  },
                ),

                // Confirm password field (only for creation)
                if (_isCreatingPassword) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    focusNode: _confirmFocusNode,
                    obscureText: _obscureConfirm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '• • • • • • • •',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 18,
                        letterSpacing: 6,
                        color: AppColors.textSecondary.withOpacity(0.3),
                      ),
                      labelText: 'Confirm Password',
                      labelStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        letterSpacing: 0,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppColors.accent, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 16),
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
                const SizedBox(height: 24),

                // Unlock / Create button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      _isCreatingPassword
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _isCreatingPassword ? 'Create Password' : 'Unlock',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ─── LEDGER DASHBOARD (Bank Cards) ────────────────────────────
// ════════════════════════════════════════════════════════════════
class _AccountLedgerSummary {
  final String accountNo;
  final double deposits;
  final double withdrawals;
  final int transactionCount;

  const _AccountLedgerSummary({
    required this.accountNo,
    required this.deposits,
    required this.withdrawals,
    required this.transactionCount,
  });

  double get balance => deposits - withdrawals;
}

class _AccountLedgerAccumulator {
  final String accountNo;
  double deposits = 0;
  double withdrawals = 0;
  int transactionCount = 0;

  _AccountLedgerAccumulator(this.accountNo);
}

String _ledgerAccountLabel(String? accountNo) {
  final trimmed = accountNo?.trim() ?? '';
  return trimmed.isEmpty ? 'Not recorded' : trimmed;
}

List<_AccountLedgerSummary> _buildAccountSummaries(List<BankLedger> entries) {
  final accounts = <String, _AccountLedgerAccumulator>{};

  for (final entry in entries) {
    final accountNo = _ledgerAccountLabel(entry.accountNo);
    final account = accounts.putIfAbsent(
      accountNo,
      () => _AccountLedgerAccumulator(accountNo),
    );
    if (entry.type == 'deposit') {
      account.deposits += entry.amount;
    } else {
      account.withdrawals += entry.amount;
    }
    account.transactionCount += 1;
  }

  final summaries = accounts.values
      .map(
        (account) => _AccountLedgerSummary(
          accountNo: account.accountNo,
          deposits: account.deposits,
          withdrawals: account.withdrawals,
          transactionCount: account.transactionCount,
        ),
      )
      .toList();

  summaries.sort((a, b) {
    if (a.accountNo == 'Not recorded') return 1;
    if (b.accountNo == 'Not recorded') return -1;
    return a.accountNo.toLowerCase().compareTo(b.accountNo.toLowerCase());
  });

  return summaries;
}

class _LedgerDashboard extends ConsumerStatefulWidget {
  const _LedgerDashboard();

  @override
  ConsumerState<_LedgerDashboard> createState() => _LedgerDashboardState();
}

class _LedgerDashboardState extends ConsumerState<_LedgerDashboard> {
  String? _selectedBank;

  // Bank card gradient palettes
  static const List<List<Color>> _bankGradients = [
    [Color(0xFF1B2A4A), Color(0xFF2D4373)],
    [Color(0xFF0D4741), Color(0xFF0E7C6B)],
    [Color(0xFF4A1942), Color(0xFF7B2D6E)],
    [Color(0xFF1A3A5C), Color(0xFF2E6B9E)],
    [Color(0xFF3D1F00), Color(0xFF8B5E3C)],
    [Color(0xFF2D1B69), Color(0xFF5B3E9E)],
    [Color(0xFF6B1D1D), Color(0xFFA93226)],
    [Color(0xFF1B4332), Color(0xFF2D6A4F)],
  ];

  static const List<IconData> _bankIcons = [
    Icons.account_balance_rounded,
    Icons.business_rounded,
    Icons.domain_rounded,
    Icons.corporate_fare_rounded,
    Icons.assured_workload_rounded,
    Icons.villa_rounded,
    Icons.storefront_rounded,
    Icons.apartment_rounded,
  ];

  void _showChangePasswordDialog(BuildContext context) {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    String? dialogError;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Change Ledger Password',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPwdCtrl,
                    obscureText: obscureOld,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          letterSpacing: 0),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPwdCtrl,
                    obscureText: obscureNew,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          letterSpacing: 0),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPwdCtrl,
                    obscureText: obscureConfirm,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          letterSpacing: 0),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.danger, size: 16),
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
                        () => dialogError = 'Enter your current password');
                    return;
                  }
                  if (newPwd.isEmpty || newPwd.length < 4) {
                    setDialogState(() =>
                        dialogError = 'New password must be at least 4 digits');
                    return;
                  }
                  if (newPwd != confirmPwd) {
                    setDialogState(
                        () => dialogError = 'New passwords do not match');
                    return;
                  }

                  final success = await PasswordService.instance
                      .changeLedgerPassword(oldPwd, newPwd);
                  if (!ctx.mounted) return;
                  if (success) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('Ledger password changed successfully',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } else {
                    setDialogState(
                        () => dialogError = 'Current password is incorrect');
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Change Password'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedBank != null) {
      return _BankDetailView(
        bankName: _selectedBank!,
        onBack: () => setState(() => _selectedBank = null),
      );
    }

    final ledgerAsync = ref.watch(ledgerProvider);
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Bank Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset_rounded),
            tooltip: 'Change Password',
            onPressed: () => _showChangePasswordDialog(context),
          ),
        ],
      ),
      body: ledgerAsync.when(
        data: (allEntries) {
          if (allEntries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No bank transactions yet',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Add your first bank entry to get started',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary.withOpacity(0.7))),
                ],
              ),
            );
          }

          // Group entries by bank name
          final Map<String, List<BankLedger>> bankGroups = {};
          for (final entry in allEntries) {
            bankGroups.putIfAbsent(entry.bankName, () => []).add(entry);
          }
          final bankNames = bankGroups.keys.toList()..sort();

          // Overall totals
          double totalDeposits = 0;
          double totalWithdrawals = 0;
          for (final e in allEntries) {
            if (e.type == 'deposit') {
              totalDeposits += e.amount;
            } else {
              totalWithdrawals += e.amount;
            }
          }
          final totalBalance = totalDeposits - totalWithdrawals;

          return Column(
            children: [
              // ─── Summary Header ───
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Balance Across All Banks',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                              fmt.format(totalBalance),
                              style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.white.withOpacity(0.8), size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _SummaryChip(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Deposits',
                          value: fmt.format(totalDeposits),
                          color: const Color(0xFF34D399),
                        ),
                        const SizedBox(width: 12),
                        _SummaryChip(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Withdrawals',
                          value: fmt.format(totalWithdrawals),
                          color: const Color(0xFFF87171),
                        ),
                        const SizedBox(width: 12),
                        _SummaryChip(
                          icon: Icons.account_balance_rounded,
                          label: 'Banks',
                          value: '${bankNames.length}',
                          color: const Color(0xFF60A5FA),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── Section Title ───
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Your Banks',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${bankNames.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ─── Bank Cards Grid ───
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.08,
                  ),
                  itemCount: bankNames.length,
                  itemBuilder: (ctx, idx) {
                    final bankName = bankNames[idx];
                    final entries = bankGroups[bankName]!;
                    double deposits = 0, withdrawals = 0;
                    for (final e in entries) {
                      if (e.type == 'deposit') {
                        deposits += e.amount;
                      } else {
                        withdrawals += e.amount;
                      }
                    }
                    final balance = deposits - withdrawals;
                    final accountSummaries = _buildAccountSummaries(entries);
                    final gradientColors =
                        _bankGradients[idx % _bankGradients.length];
                    final icon = _bankIcons[idx % _bankIcons.length];

                    return _BankCard(
                      bankName: bankName,
                      balance: balance,
                      deposits: deposits,
                      withdrawals: withdrawals,
                      accountSummaries: accountSummaries,
                      transactionCount: entries.length,
                      gradientColors: gradientColors,
                      icon: icon,
                      onTap: () => setState(() => _selectedBank = bankName),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context, builder: (ctx) => const AddLedgerDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Entry'),
      ),
    );
  }
}

// ─── Summary chip (inside header) ────────────────────────────
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500)),
                  Text(value,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bank Card Widget ─────────────────────────────────────────
class _BankCard extends StatefulWidget {
  final String bankName;
  final double balance;
  final double deposits;
  final double withdrawals;
  final List<_AccountLedgerSummary> accountSummaries;
  final int transactionCount;
  final List<Color> gradientColors;
  final IconData icon;
  final VoidCallback onTap;

  const _BankCard({
    required this.bankName,
    required this.balance,
    required this.deposits,
    required this.withdrawals,
    required this.accountSummaries,
    required this.transactionCount,
    required this.gradientColors,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_BankCard> createState() => _BankCardState();
}

class _BankCardState extends State<_BankCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0]
                    .withOpacity(_isHovered ? 0.4 : 0.2),
                blurRadius: _isHovered ? 24 : 12,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background decorative circle
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(widget.icon,
                              color: Colors.white.withOpacity(0.9), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.bankName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withOpacity(0.4), size: 14),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Balance',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmt.format(widget.balance),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _AccountAnalyticsList(
                        accountSummaries: widget.accountSummaries,
                        fmt: fmt,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MiniStat(
                          icon: Icons.arrow_downward_rounded,
                          value: fmt.format(widget.deposits),
                          color: const Color(0xFF34D399),
                        ),
                        const SizedBox(width: 16),
                        _MiniStat(
                          icon: Icons.arrow_upward_rounded,
                          value: fmt.format(widget.withdrawals),
                          color: const Color(0xFFF87171),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.transactionCount} txns',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _AccountAnalyticsList extends StatelessWidget {
  final List<_AccountLedgerSummary> accountSummaries;
  final NumberFormat fmt;

  const _AccountAnalyticsList({
    required this.accountSummaries,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (accountSummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: accountSummaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final account = accountSummaries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white.withOpacity(0.58), size: 12),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'A/C ${account.accountNo}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  fmt.format(account.balance),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'D ${fmt.format(account.deposits)} • W ${fmt.format(account.withdrawals)} • ${account.transactionCount} txns',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ─── BANK DETAIL VIEW ─────────────────────────────────────────
// ════════════════════════════════════════════════════════════════
class _BankDetailView extends ConsumerStatefulWidget {
  final String bankName;
  final VoidCallback onBack;

  const _BankDetailView({required this.bankName, required this.onBack});

  @override
  ConsumerState<_BankDetailView> createState() => _BankDetailViewState();
}

class _BankDetailViewState extends ConsumerState<_BankDetailView> {
  DateTimeRange? _dateRange;

  void _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  void _clearDateRange() => setState(() => _dateRange = null);

  void _pickMonth() async {
    final date = await showMonthYearPicker(context, onlyYear: false);
    if (date != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: DateTime(date.year, date.month, 1),
          end: DateTime(date.year, date.month + 1, 0),
        );
      });
    }
  }

  void _pickYear() async {
    final date = await showMonthYearPicker(context, onlyYear: true);
    if (date != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: DateTime(date.year, 1, 1),
          end: DateTime(date.year, 12, 31),
        );
      });
    }
  }

  void _setPresetDateRange(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (preset == 'week') {
      start = now.subtract(Duration(days: now.weekday - 1));
    } else if (preset == 'month') {
      start = DateTime(now.year, now.month, 1);
    } else if (preset == 'year') {
      start = DateTime(now.year, 1, 1);
    } else {
      _clearDateRange();
      return;
    }
    setState(() => _dateRange = DateTimeRange(start: start, end: end));
  }

  bool _isWithinRange(String dateStr) {
    if (_dateRange == null) return true;
    final date = DateTime.parse(dateStr);
    return date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
        date.isBefore(_dateRange!.end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(ledgerProvider);
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('EEE, MMM dd, yyyy');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        title: Text(widget.bankName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Ledger',
            onSelected: (value) {
              if (value == 'custom') {
                _pickDateRange();
              } else if (value == 'pick_month') {
                _pickMonth();
              } else if (value == 'pick_year') {
                _pickYear();
              } else {
                _setPresetDateRange(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Time')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
              const PopupMenuItem(value: 'year', child: Text('This Year')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'pick_month', child: Text('Select Month...')),
              const PopupMenuItem(
                  value: 'pick_year', child: Text('Select Year...')),
              const PopupMenuItem(
                  value: 'custom', child: Text('Custom Date Range...')),
            ],
          ),
          if (_dateRange != null)
            IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: _clearDateRange,
                tooltip: 'Clear Filter'),
        ],
      ),
      body: ledgerAsync.when(
        data: (allEntries) {
          final entries = allEntries
              .where((e) =>
                  e.bankName == widget.bankName && _isWithinRange(e.date))
              .toList();

          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No transactions found',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                      _dateRange != null
                          ? 'Try adjusting the date filter'
                          : 'Add entries for ${widget.bankName}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary.withOpacity(0.7))),
                ],
              ),
            );
          }

          double deposits = 0, withdrawals = 0;
          for (var e in entries) {
            if (e.type == 'deposit') {
              deposits += e.amount;
            } else {
              withdrawals += e.amount;
            }
          }
          final balance = deposits - withdrawals;

          return Column(
            children: [
              // ─── Bank Balance Header ───
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Balance',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Text(
                              fmt.format(balance),
                              style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final List<List<String>> data = entries
                                .map<List<String>>((e) => <String>[
                                      fmtDate.format(DateTime.parse(e.date)),
                                      e.type.toUpperCase(),
                                      _ledgerAccountLabel(e.accountNo),
                                      e.purpose ?? '-',
                                      fmt.format(e.amount)
                                    ])
                                .toList();

                            await PdfService.generateAndPrintPdf(
                              title: '${widget.bankName} – Bank Ledger Report',
                              subtitle: _dateRange != null
                                  ? 'From: ${fmtDate.format(_dateRange!.start)} To: ${fmtDate.format(_dateRange!.end)}'
                                  : 'All Time',
                              headers: [
                                'Date',
                                'Type',
                                'Account No',
                                'Purpose',
                                'Amount'
                              ],
                              data: data,
                              totalAmountLabel: 'Closing Balance:',
                              totalAmount: fmt.format(balance),
                            );
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded,
                              size: 18),
                          label: const Text('PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.15),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_downward_rounded,
                                    color: Color(0xFF34D399), size: 16),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Deposits',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.white54)),
                                    Text(fmt.format(deposits),
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded,
                                    color: Color(0xFFF87171), size: 16),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Withdrawals',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.white54)),
                                    Text(fmt.format(withdrawals),
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── Date filter indicator ───
              if (_dateRange != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.info.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_rounded,
                            color: AppColors.info, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${fmtDate.format(_dateRange!.start)} – ${fmtDate.format(_dateRange!.end)}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.info),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _clearDateRange,
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.info, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // ─── Transaction List ───
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: entries.length,
                  itemBuilder: (ctx, idx) {
                    final entry = entries[idx];
                    final isDeposit = entry.type == 'deposit';
                    final accentColor =
                        isDeposit ? AppColors.success : AppColors.danger;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                            left: BorderSide(color: accentColor, width: 4)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isDeposit
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: accentColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          entry.type.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        fmtDate
                                            .format(DateTime.parse(entry.date)),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    fmt.format(entry.amount),
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'A/C: ${_ledgerAccountLabel(entry.accountNo)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isDeposit &&
                                      entry.purpose != null &&
                                      entry.purpose!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.description_rounded,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Purpose: ${entry.purpose!.trim()}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => showDialog(
                                      context: context,
                                      builder: (ctx) => AddLedgerDialog(
                                          existingEntry: entry)),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.edit_rounded,
                                        size: 18,
                                        color: AppColors.info.withOpacity(0.7)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => ref
                                      .read(ledgerProvider.notifier)
                                      .deleteLedgerEntry(entry.id!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.delete_outline_rounded,
                                        size: 18,
                                        color:
                                            AppColors.danger.withOpacity(0.7)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context, builder: (ctx) => const AddLedgerDialog()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Entry'),
      ),
    );
  }
}
