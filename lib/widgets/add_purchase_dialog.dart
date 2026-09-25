import 'package:flutter/material.dart';
import 'save_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

import '../widgets/agency_code_dropdown.dart';
import '../main.dart';

class AddPurchaseDialog extends ConsumerStatefulWidget {
  final TransactionModel? existingTx;
  const AddPurchaseDialog({super.key, this.existingTx});

  @override
  ConsumerState<AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _AddPurchaseDialogState extends ConsumerState<AddPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _agencyNameCtrl = TextEditingController();
  final _agencyCodeCtrl = TextEditingController();
  final _billNoCtrl = TextEditingController();

  String _purchaseType = 'purchase_cash';
  DateTime _billDate = DateTime.now();
  DateTime _entryDate = DateTime.now();
  bool _isSaving = false;
  bool _agencyLocked = false; // True when name was auto-filled from registry

  @override
  void initState() {
    super.initState();
    if (widget.existingTx != null) {
      _amountCtrl.text = widget.existingTx!.totalAmount.toString();
      _agencyNameCtrl.text = widget.existingTx!.agencyName ?? '';
      _agencyCodeCtrl.text = widget.existingTx!.agencyCode ?? '';
      _billNoCtrl.text = widget.existingTx!.billNo ?? '';
      _purchaseType = widget.existingTx!.type;
      if (widget.existingTx!.billDate != null) {
        _billDate = DateTime.parse(widget.existingTx!.billDate!);
      }
      try {
        _entryDate = DateTime.parse(widget.existingTx!.date);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _agencyNameCtrl.dispose();
    _agencyCodeCtrl.dispose();
    _billNoCtrl.dispose();
    super.dispose();
  }

  void _savePurchase() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final tx = TransactionModel(
      id: widget.existingTx?.id,
      type: _purchaseType,
      date: _entryDate.toIso8601String(),
      totalAmount: double.parse(_amountCtrl.text),
      agencyName: _agencyNameCtrl.text,
      agencyCode: _agencyCodeCtrl.text,
      billNo: _billNoCtrl.text,
      billDate: _billDate.toIso8601String(),
      paidAmount: widget.existingTx?.paidAmount ?? 0,
    );

    final saved = await saveEntry(context, (allowDuplicate) async {
      final notifier = ref.read(transactionsProvider.notifier);
      if (widget.existingTx != null) {
        await notifier.updateTransaction(tx, allowDuplicate: allowDuplicate);
      } else {
        await notifier.addTransaction(tx, allowDuplicate: allowDuplicate);
      }
    });
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.of(context).pop();
  }

  Widget _dateRow(
      String label, DateTime date, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime.now());
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.1,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, MMM dd, yyyy').format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_rounded,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
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
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.shopping_cart_rounded,
                            color: AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text('Add Purchase',
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

                  _dateRow('Entry Date', _entryDate,
                      (d) => setState(() => _entryDate = d)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _purchaseType,
                    decoration:
                        const InputDecoration(labelText: 'Purchase Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'purchase_cash', child: Text('Cash Purchase')),
                      DropdownMenuItem(
                          value: 'purchase_credit',
                          child: Text('Credit Purchase')),
                    ],
                    onChanged: (val) => setState(() => _purchaseType = val!),
                  ),
                  const SizedBox(height: 16),

                  // Agency Code — searchable dropdown
                  AgencyCodeDropdown(
                    codeController: _agencyCodeCtrl,
                    nameController: _agencyNameCtrl,
                    onAgencyLocked: (locked) =>
                        setState(() => _agencyLocked = locked),
                  ),
                  const SizedBox(height: 16),

                  // Agency Name — auto-filled & shows hint when locked
                  TextFormField(
                    controller: _agencyNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Agency Name',
                      helperText:
                          _agencyLocked ? '✓ Auto-filled from registry' : null,
                      helperStyle: GoogleFonts.inter(
                          color: AppColors.success, fontSize: 11),
                      suffixIcon: _agencyLocked
                          ? IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              tooltip: 'Edit name (will update registry)',
                              onPressed: () =>
                                  setState(() => _agencyLocked = false),
                            )
                          : null,
                    ),
                    readOnly: _agencyLocked,
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: TextFormField(
                              controller: _billNoCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Bill No',
                                  helperText: 'Must be unique for this agency',
                                  helperMaxLines: 2),
                              validator: (val) => (val == null || val.isEmpty)
                                  ? 'Required'
                                  : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _dateRow('Bill Date', _billDate,
                              (d) => setState(() => _billDate = d))),
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
                      if (double.tryParse(val) == null) return 'Invalid Number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _savePurchase,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(widget.existingTx != null
                            ? 'Update'
                            : 'Save Purchase'),
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
