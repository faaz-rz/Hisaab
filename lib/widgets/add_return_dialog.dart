import 'package:flutter/material.dart';
import 'save_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

import '../widgets/agency_code_dropdown.dart';
import '../main.dart';

class AddReturnDialog extends ConsumerStatefulWidget {
  const AddReturnDialog({super.key});

  @override
  ConsumerState<AddReturnDialog> createState() => _AddReturnDialogState();
}

class _AddReturnDialogState extends ConsumerState<AddReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _agencyNameCtrl = TextEditingController();
  final _agencyCodeCtrl = TextEditingController();
  final _creditNoteNoCtrl = TextEditingController();
  DateTime _creditNoteDate = DateTime.now();
  final _adjDetailsCtrl = TextEditingController();
  DateTime _entryDate = DateTime.now();

  bool _isSaving = false;
  bool _agencyLocked = false;

  // Credit note: unpaid bills for the selected agency
  List<TransactionModel> _unpaidBills = [];
  TransactionModel? _selectedBill;
  bool _loadingBills = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _agencyNameCtrl.dispose();
    _agencyCodeCtrl.dispose();
    _creditNoteNoCtrl.dispose();
    _adjDetailsCtrl.dispose();
    super.dispose();
  }


  Future<void> _onAgencyNameChanged(String name) async {
    if (name.trim().isNotEmpty) {
      await _loadUnpaidBills();
    }
  }

  Future<void> _loadUnpaidBills() async {
    final code = _agencyCodeCtrl.text.trim();
    final name = _agencyNameCtrl.text.trim();
    if (code.isEmpty && name.isEmpty) return;

    setState(() => _loadingBills = true);
    try {
      final bills = await TransactionNotifier.getCreditPurchasesByAgency(
        agencyCode: code.isNotEmpty ? code : null,
        agencyName: code.isEmpty ? name : null,
      );
      if (mounted) {
        setState(() {
          _unpaidBills = bills;
          _selectedBill = null;
          _loadingBills = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBills = false);
    }
  }

  void _selectBill(TransactionModel bill) {
    setState(() {
      _selectedBill = bill;
    });
  }

  void _saveReturn() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text);

    // Validate credit note amount against selected bill
    if (_selectedBill != null) {
      if (amount > _selectedBill!.remainingAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Amount exceeds remaining balance of ₹${_selectedBill!.remainingAmount.toStringAsFixed(0)}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final tx = TransactionModel(
      type: 'credit_note',
      date: _entryDate.toIso8601String(),
      totalAmount: amount,
      agencyName: _agencyNameCtrl.text,
      agencyCode: _agencyCodeCtrl.text,
      originalBillNo: _creditNoteNoCtrl.text,
      adjustmentDetails: _adjDetailsCtrl.text,
      billDate: _creditNoteDate.toIso8601String(),
      billNo: _selectedBill?.billNo,
    );

    final saved = await saveEntry(context, (allowDuplicate) =>
        ref.read(transactionsProvider.notifier).addTransaction(tx,
            allowDuplicate: allowDuplicate, linkedBillId: _selectedBill?.id));
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.of(context).pop();
  }

  Widget _dateRow(String label, DateTime date, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                Text(DateFormat('EEE, MMM dd, yyyy').format(date), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_rounded, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Builds the selectable unpaid bills list for credit note mode
  Widget _buildUnpaidBillsList() {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('EEE, MMM dd, yyyy');

    if (_loadingBills) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_agencyCodeCtrl.text.trim().isEmpty && _agencyNameCtrl.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_unpaidBills.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No unpaid credit purchase bills found for this agency',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Text(
              'Select Bill to Apply Credit Note',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _unpaidBills.length,
            itemBuilder: (ctx, idx) {
              final bill = _unpaidBills[idx];
              final isSelected = _selectedBill?.id == bill.id;

              return GestureDetector(
                onTap: () => _selectBill(bill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    children: [
                      // Selection indicator
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.accent : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.accent : AppColors.textSecondary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Bill details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Bill: ${bill.billNo ?? "N/A"}',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                if (bill.billDate != null)
                                  Text(
                                    fmtDate.format(DateTime.parse(bill.billDate!)),
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Total: ${fmt.format(bill.totalAmount)}',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Remaining: ${fmt.format(bill.remainingAmount)}',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger),
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
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.note_alt_rounded, color: Colors.purple, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text('Credit Note', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary), style: IconButton.styleFrom(backgroundColor: AppColors.surface)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 24),

                  _dateRow('Entry Date', _entryDate, (d) => setState(() => _entryDate = d)),
                  const SizedBox(height: 16),

                  // Agency Code with searchable dropdown
                  AgencyCodeDropdown(
                    codeController: _agencyCodeCtrl,
                    nameController: _agencyNameCtrl,
                    onAgencyLocked: (locked) {
                      setState(() => _agencyLocked = locked);
                      if (locked) {
                        _loadUnpaidBills();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agencyNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Agency Name',
                      helperText: _agencyLocked ? '✓ Auto-filled from registry' : null,
                      helperStyle: GoogleFonts.inter(color: AppColors.success, fontSize: 11),
                      suffixIcon: _agencyLocked ? IconButton(icon: const Icon(Icons.edit_rounded, size: 18), onPressed: () => setState(() => _agencyLocked = false)) : null,
                    ),
                    readOnly: _agencyLocked,
                    onChanged: _agencyLocked ? null : _onAgencyNameChanged,
                    validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Show unpaid bills for selection
                  _buildUnpaidBillsList(),

                  if (_selectedBill != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Applying to Bill: ${_selectedBill!.billNo ?? "N/A"} — Remaining: ₹${_selectedBill!.remainingAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextFormField(controller: _creditNoteNoCtrl, decoration: const InputDecoration(labelText: 'Credit Note Number'), validator: (val) => (val == null || val.isEmpty) ? 'Required' : null),
                  const SizedBox(height: 16),
                  _dateRow('Credit Note Date', _creditNoteDate, (d) => setState(() => _creditNoteDate = d)),
                  const SizedBox(height: 16),
                  TextFormField(controller: _adjDetailsCtrl, decoration: const InputDecoration(labelText: 'Adjustment Details')),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Credit Note Amount',
                      prefixText: '₹ ',
                      helperText: _selectedBill != null
                          ? 'Max: ₹${_selectedBill!.remainingAmount.toStringAsFixed(0)}'
                          : null,
                      helperStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.info),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid';
                      if (_selectedBill != null) {
                        final amount = double.parse(val);
                        if (amount > _selectedBill!.remainingAmount) {
                          return 'Exceeds remaining ₹${_selectedBill!.remainingAmount.toStringAsFixed(0)}';
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveReturn,
                        icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save'),
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
