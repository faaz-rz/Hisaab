import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bank_ledger.dart';
import '../providers/ledger_provider.dart';
import '../services/bank_service.dart';
import '../main.dart';

class AddLedgerDialog extends ConsumerStatefulWidget {
  final BankLedger? existingEntry;
  const AddLedgerDialog({super.key, this.existingEntry});

  @override
  ConsumerState<AddLedgerDialog> createState() => _AddLedgerDialogState();
}

class _AddLedgerDialogState extends ConsumerState<AddLedgerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankCodeCtrl = TextEditingController();
  final _accountNoCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _accountNoFocusNode = FocusNode();

  String _txType = 'deposit';
  DateTime _entryDate = DateTime.now();
  bool _isSaving = false;
  bool _bankLocked = false;

  List<Map<String, dynamic>> _banks = [];
  List<String> _accountOptions = [];
  bool _banksLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    if (widget.existingEntry != null) {
      _amountCtrl.text = widget.existingEntry!.amount.toString();
      _bankNameCtrl.text = widget.existingEntry!.bankName;
      _bankCodeCtrl.text = widget.existingEntry!.bankCode ?? '';
      _accountNoCtrl.text = widget.existingEntry!.accountNo ?? '';
      _purposeCtrl.text = widget.existingEntry!.purpose ?? '';
      _txType = widget.existingEntry!.type;
      try {
        _entryDate = DateTime.parse(widget.existingEntry!.date);
      } catch (_) {}
      _loadAccountOptionsForBank(
        widget.existingEntry!.bankName,
        preferredAccountNo: widget.existingEntry!.accountNo,
      );
    }
  }

  Future<void> _loadBanks() async {
    final banks = await BankService.instance.getAllBanks();
    if (mounted) {
      setState(() {
        _banks = banks;
        _banksLoaded = true;
      });
    }
  }

  Future<void> _loadAccountOptionsForBank(
    String bankName, {
    String? preferredAccountNo,
  }) async {
    final rows = await BankService.instance.getAccountsForBank(bankName);
    if (!mounted) return;
    if (_bankNameCtrl.text.trim() != bankName.trim()) return;

    final options = rows
        .map((row) => (row['account_no'] as String?)?.trim() ?? '')
        .where((accountNo) => accountNo.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    setState(() {
      _accountOptions = options;
      final preferred =
          preferredAccountNo?.trim() ?? _accountNoCtrl.text.trim();
      if (preferred.isNotEmpty) {
        _accountNoCtrl.text = preferred;
      } else if (options.length == 1) {
        _accountNoCtrl.text = options.first;
      } else {
        _accountNoCtrl.clear();
      }
    });
  }

  void _onBankSelected(Map<String, dynamic> bank) {
    final bankName = bank['bank_name'] as String;
    setState(() {
      _bankNameCtrl.text = bankName;
      _bankCodeCtrl.text = (bank['bank_code'] as String?) ?? '';
      _bankLocked = true;
    });
    _loadAccountOptionsForBank(bankName);
  }

  Future<void> _onBankNameChanged(String name) async {
    if (name.trim().isEmpty) {
      setState(() {
        _bankLocked = false;
        _accountOptions = [];
        _accountNoCtrl.clear();
      });
      return;
    }
    final bank = await BankService.instance.getBankByName(name);
    if (bank != null && mounted) {
      setState(() {
        _bankCodeCtrl.text = (bank['bank_code'] as String?) ?? '';
        _bankLocked = true;
      });
      await _loadAccountOptionsForBank(
        name,
        preferredAccountNo: _accountNoCtrl.text,
      );
    } else {
      setState(() {
        _bankLocked = false;
        _accountOptions = [];
      });
    }
  }

  Future<void> _onBankCodeChanged(String code) async {
    if (code.trim().isEmpty) {
      setState(() => _bankLocked = false);
      return;
    }
    final bank = await BankService.instance.getBankByCode(code);
    if (bank != null && mounted) {
      final bankName = (bank['bank_name'] as String?) ?? '';
      setState(() {
        _bankNameCtrl.text = bankName;
        _bankLocked = true;
      });
      await _loadAccountOptionsForBank(
        bankName,
        preferredAccountNo: _accountNoCtrl.text,
      );
    } else {
      setState(() => _bankLocked = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankCodeCtrl.dispose();
    _accountNoCtrl.dispose();
    _accountNoFocusNode.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  void _saveLedgerEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final entry = BankLedger(
      id: widget.existingEntry?.id,
      type: _txType,
      bankName: _bankNameCtrl.text.trim(),
      bankCode: _bankCodeCtrl.text.trim(),
      accountNo: _accountNoCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text),
      date: _entryDate.toIso8601String(),
      purpose: _txType == 'withdrawal' ? _purposeCtrl.text : null,
    );

    // Save bank details to registry
    await BankService.instance.saveBank(
      _bankNameCtrl.text.trim(),
      bankCode: _bankCodeCtrl.text.trim(),
      accountNo: _accountNoCtrl.text.trim(),
    );

    if (widget.existingEntry != null) {
      await ref.read(ledgerProvider.notifier).updateLedgerEntry(entry);
    } else {
      await ref.read(ledgerProvider.notifier).addLedgerEntry(entry);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.account_balance_rounded,
                            color: AppColors.info, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text('Bank Ledger Entry',
                          style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.textSecondary),
                          style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 24),

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _entryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (picked != null) setState(() => _entryDate = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.accent),
                          const SizedBox(width: 12),
                          Text(
                              DateFormat('EEEE, MMM dd, yyyy')
                                  .format(_entryDate),
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          const Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _txType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'deposit', child: Text('Deposit')),
                      DropdownMenuItem(
                          value: 'withdrawal', child: Text('Withdrawal')),
                    ],
                    onChanged: (val) => setState(() => _txType = val!),
                  ),
                  const SizedBox(height: 16),

                  // Bank Name — searchable autocomplete dropdown
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (textEditingValue) {
                      if (!_banksLoaded) return _banks;
                      if (textEditingValue.text.isEmpty) return _banks;
                      final query = textEditingValue.text.toLowerCase();
                      return _banks.where((b) {
                        final name = (b['bank_name'] as String).toLowerCase();
                        final code =
                            ((b['bank_code'] as String?) ?? '').toLowerCase();
                        return name.contains(query) || code.contains(query);
                      });
                    },
                    displayStringForOption: (bank) =>
                        bank['bank_name'] as String,
                    onSelected: _onBankSelected,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      // Sync initial value
                      if (_bankNameCtrl.text.isNotEmpty &&
                          controller.text.isEmpty) {
                        controller.text = _bankNameCtrl.text;
                      }
                      controller.addListener(() {
                        if (_bankNameCtrl.text != controller.text) {
                          _bankNameCtrl.text = controller.text;
                        }
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Bank Name',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_bankLocked)
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 18),
                              if (_banksLoaded)
                                const Icon(Icons.arrow_drop_down_rounded,
                                    color: AppColors.textSecondary, size: 24),
                            ],
                          ),
                        ),
                        onChanged: (val) {
                          _bankNameCtrl.text = val;
                          _onBankNameChanged(val);
                        },
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          shadowColor: Colors.black26,
                          child: Container(
                            constraints: const BoxConstraints(
                                maxHeight: 220, maxWidth: 400),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (ctx, idx) {
                                final bank = options.elementAt(idx);
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.info.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_rounded,
                                        color: AppColors.info,
                                        size: 18),
                                  ),
                                  title: Text(
                                    bank['bank_name'] as String,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                  subtitle: Text(
                                    'Code: ${(bank['bank_code'] as String?) ?? 'N/A'} • ${((bank['account_count'] as num?)?.toInt() ?? 0)} saved account(s)',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                  onTap: () => onSelected(bank),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_bankLocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_fix_high_rounded,
                              size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('Bank details auto-filled',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppColors.success)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _bankLocked = false),
                            child: Text('Edit',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bankCodeCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Bank Code'),
                          readOnly: _bankLocked,
                          onChanged: _bankLocked ? null : _onBankCodeChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RawAutocomplete<String>(
                          textEditingController: _accountNoCtrl,
                          focusNode: _accountNoFocusNode,
                          optionsBuilder: (textEditingValue) {
                            if (_accountOptions.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            final query =
                                textEditingValue.text.trim().toLowerCase();
                            if (query.isEmpty) return _accountOptions;
                            return _accountOptions.where((accountNo) =>
                                accountNo.toLowerCase().contains(query));
                          },
                          onSelected: (accountNo) {
                            _accountNoCtrl.text = accountNo;
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Account No',
                                helperText: _accountOptions.isEmpty
                                    ? null
                                    : '${_accountOptions.length} saved account(s)',
                                suffixIcon: _accountOptions.isNotEmpty
                                    ? const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        color: AppColors.textSecondary,
                                      )
                                    : null,
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(12),
                                shadowColor: Colors.black26,
                                child: Container(
                                  constraints: const BoxConstraints(
                                      maxHeight: 190, maxWidth: 220),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppColors.divider),
                                  ),
                                  child: ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (ctx, idx) {
                                      final accountNo = options.elementAt(idx);
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: AppColors.accent,
                                          size: 18,
                                        ),
                                        title: Text(
                                          accountNo,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        onTap: () => onSelected(accountNo),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Amount', prefixText: '₹ '),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null ||
                          double.parse(val) <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                  if (_txType == 'withdrawal') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _purposeCtrl,
                        decoration: const InputDecoration(labelText: 'Purpose'),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'Required for withdrawals'
                            : null),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveLedgerEntry,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(widget.existingEntry != null
                            ? 'Update'
                            : 'Save Entry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
