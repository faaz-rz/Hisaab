import 'package:flutter/material.dart';
import 'save_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../main.dart';

class AddSaleDialog extends ConsumerStatefulWidget {
  final TransactionModel? existingTx;
  const AddSaleDialog({super.key, this.existingTx});

  @override
  ConsumerState<AddSaleDialog> createState() => _AddSaleDialogState();
}

class _AddSaleDialogState extends ConsumerState<AddSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _salesCtrl = TextEditingController();
  final _profitPctCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _profitCtrl = TextEditingController();

  bool _isSaving = false;
  DateTime _entryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingTx != null) {
      final total = widget.existingTx!.totalAmount;
      final upi = widget.existingTx!.upiAmount ?? 0.0;
      _salesCtrl.text = total > 0 ? total.toString() : '';
      _upiCtrl.text = upi > 0 ? upi.toString() : '';
      _profitCtrl.text = widget.existingTx!.profit?.toString() ?? '';
      try {
        _entryDate = DateTime.parse(widget.existingTx!.date);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _salesCtrl.dispose();
    _profitPctCtrl.dispose();
    _upiCtrl.dispose();
    _profitCtrl.dispose();
    super.dispose();
  }

  void _saveSale() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final total = _salesCtrl.text.isEmpty ? 0.0 : double.parse(_salesCtrl.text);
    final upi = _upiCtrl.text.isEmpty ? 0.0 : double.parse(_upiCtrl.text);

    final tx = TransactionModel(
      id: widget.existingTx?.id,
      type: 'sale',
      date: _entryDate.toIso8601String(),
      totalAmount: total,
      upiAmount: upi,
      profit: _profitCtrl.text.isNotEmpty
          ? double.parse(_profitCtrl.text)
          : _profitPctCtrl.text.isNotEmpty
              ? total * double.parse(_profitPctCtrl.text) / 100
              : null,
      discount: widget.existingTx?.discount,
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
                  // ─── Header ───
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded,
                            color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(
                        widget.existingTx != null
                            ? 'Edit Sale'
                            : 'Add Daily Sale',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      )),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary),
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 24),

                  // ─── Date Picker ───
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _entryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _entryDate = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
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
                              child: Text(
                            DateFormat('EEEE, MMM dd, yyyy').format(_entryDate),
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary),
                          )),
                          const Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 24),
                    child: Text(
                        'One sales entry per day, per profile. To change a recorded amount, edit the existing sale.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),

                  // ─── Sales Amount ───
                  TextFormField(
                    controller: _salesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Sales Amount', prefixText: '₹ '),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid Number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ─── UPI ───
                  TextFormField(
                    controller: _upiCtrl,
                    decoration: const InputDecoration(
                      labelText: 'UPI Payment',
                      prefixText: '₹ ',
                      helperText: 'Included in Total Sales Amount',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val != null &&
                          val.isNotEmpty &&
                          double.tryParse(val) == null) return 'Invalid Number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ─── Profit Section ───
                  Text('Profit',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _profitPctCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Profit %',
                            suffixText: '%',
                            helperText: 'Auto-calculate',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val != null &&
                                val.isNotEmpty &&
                                double.tryParse(val) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _profitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Manual Override',
                            prefixText: '₹ ',
                            helperText: 'Overrides %',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val != null &&
                                val.isNotEmpty &&
                                double.tryParse(val) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // Live preview
                  if (_profitPctCtrl.text.isNotEmpty &&
                      _salesCtrl.text.isNotEmpty &&
                      _profitCtrl.text.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Builder(builder: (_) {
                        final sales = double.tryParse(_salesCtrl.text) ?? 0;
                        final pct = double.tryParse(_profitPctCtrl.text) ?? 0;
                        final calc = sales * pct / 100;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_rounded,
                                  size: 18, color: AppColors.success),
                              const SizedBox(width: 8),
                              Text(
                                'Calculated Profit: ₹${calc.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 28),

                  // ─── Actions ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveSale,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                            widget.existingTx != null ? 'Update' : 'Save Sale'),
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
