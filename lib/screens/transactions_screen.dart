import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/add_sale_dialog.dart';
import '../widgets/add_purchase_dialog.dart';
import '../widgets/add_return_dialog.dart';
import '../widgets/add_credit_payment_dialog.dart';
import '../services/password_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/password_auth_gate.dart';
import '../mixins/date_filter_mixin.dart';
import '../main.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin, DateFilterMixin<TransactionsScreen> {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _salesAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _paymentMethodLabel(TransactionModel tx) {
    if (tx.paymentMethod == 'cash') return 'Cash';
    if (tx.paymentMethod == 'upi') return 'UPI';
    if (tx.type == 'credit_note') return 'Credit Note';
    return 'Method not recorded';
  }

  String _historyTypeLabel(TransactionModel tx) {
    return tx.type == 'credit_note' ? 'Credit Note' : 'Credit Payment';
  }

  Color _historyTypeColor(TransactionModel tx) {
    return tx.type == 'credit_note' ? Colors.purple : AppColors.info;
  }

  DateTime _purchaseSortDate(TransactionModel tx) {
    return DateTime.tryParse(tx.billDate ?? tx.date) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _comparePurchasesByBillDateDesc(TransactionModel a, TransactionModel b) {
    final dateCompare = _purchaseSortDate(b).compareTo(_purchaseSortDate(a));
    if (dateCompare != 0) return dateCompare;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  }

  String _filterDateFor(TransactionModel tx) {
    if (tx.type.startsWith('purchase')) return tx.billDate ?? tx.date;
    return tx.date;
  }

  String _searchHintFor(String filterType) {
    if (filterType == 'sale') {
      return 'Search sales by amount, date, or payment...';
    }
    if (filterType == 'purchase') {
      return 'Search by agency name, code, or bill no...';
    }
    return 'Search payments by agency, bill, receipt, or method...';
  }

  bool _matchesTransactionSearch(TransactionModel tx) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final fields = [
      tx.type,
      tx.date,
      tx.billDate,
      tx.agencyName,
      tx.agencyCode,
      tx.billNo,
      tx.originalBillNo,
      tx.paymentMethod,
      tx.receiptNo,
      tx.adjustmentDetails,
      tx.totalAmount.toStringAsFixed(0),
      tx.paidAmount.toStringAsFixed(0),
      tx.remainingAmount.toStringAsFixed(0),
    ];

    return fields
        .whereType<String>()
        .any((value) => value.toLowerCase().contains(query));
  }

  Future<void> _confirmDeleteTransaction(TransactionModel tx) async {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final confirmed = await confirmDeleteDialog(
      context,
      title: 'Delete Transaction',
      message: 'This transaction will be permanently removed.',
      details:
          '${tx.type.toUpperCase().replaceAll('_', ' ')} • ${fmt.format(tx.totalAmount)}',
    );
    if (!confirmed || !mounted || tx.id == null) return;
    await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id!);
  }

  void _showPaymentHistorySheet(BuildContext context, TransactionModel bill) {
    final billNo = bill.billNo ?? '';
    final historyFuture = TransactionNotifier.getPaymentHistoryForBill(billNo);
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtDate = DateFormat('EEE, MMM dd, yyyy');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.38,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: Colors.deepOrange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment History',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${bill.agencyName ?? 'Unknown Agency'} - Bill ${bill.billNo ?? '-'}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HistorySummaryItem(
                            label: 'Bill Total',
                            value: fmt.format(bill.totalAmount),
                          ),
                        ),
                        Container(
                            width: 1, height: 36, color: AppColors.divider),
                        Expanded(
                          child: _HistorySummaryItem(
                            label: 'Paid/Adjusted',
                            value: fmt.format(bill.paidAmount),
                          ),
                        ),
                        Container(
                            width: 1, height: 36, color: AppColors.divider),
                        Expanded(
                          child: _HistorySummaryItem(
                            label: 'Remaining',
                            value: fmt.format(bill.remainingAmount),
                            valueColor: bill.remainingAmount > 0
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<TransactionModel>>(
                    future: historyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Expanded(
                            child: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              'Unable to load payment history',
                              style: GoogleFonts.inter(color: AppColors.danger),
                            ),
                          ),
                        );
                      }

                      final history = snapshot.data ?? [];
                      if (history.isEmpty) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              'No payments or credit notes recorded for this bill',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      }

                      return Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final tx = history[index];
                            final accentColor = _historyTypeColor(tx);
                            final receiptNo = tx.receiptNo?.trim();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                    left: BorderSide(
                                        color: accentColor, width: 3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      tx.type == 'credit_note'
                                          ? Icons.note_alt_rounded
                                          : Icons.payment_rounded,
                                      color: accentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: accentColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _historyTypeLabel(tx),
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: accentColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              fmtDate.format(
                                                  DateTime.parse(tx.date)),
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _paymentMethodLabel(tx),
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (receiptNo != null &&
                                            receiptNo.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Receipt: $receiptNo',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    fmt.format(tx.totalAmount),
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          if (_salesAuthenticated)
            IconButton(
              icon: const Icon(Icons.lock_reset_rounded),
              tooltip: 'Change Sales Password',
              onPressed: () => showChangePasswordDialog(
                context,
                title: 'Change Sales Password',
                successMessage: 'Sales password changed successfully',
                changePassword: PasswordService.instance.changeSalesPassword,
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Transactions',
            onSelected: handleDateFilterSelection,
            itemBuilder: (context) => buildFilterMenu(allLabel: 'All Time'),
          ),
          if (dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: clearDateRange,
              tooltip: 'Clear Filter',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Sales'),
                Tab(text: 'Purchases'),
                Tab(text: 'Payments'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _salesAuthenticated
              ? _buildTxList(context, ref, 'sale')
              : PasswordAuthGate(
                  title: 'Sales Data',
                  createMessage: 'Create a password to protect sales data',
                  verifyMessage: 'Enter password to view',
                  icon: Icons.lock_rounded,
                  isPasswordSet: PasswordService.instance.isSalesPasswordSet,
                  setPassword: PasswordService.instance.setSalesPassword,
                  verifyPassword: PasswordService.instance.verifySalesPassword,
                  onSuccess: () => setState(() => _salesAuthenticated = true),
                  width: 380,
                ),
          _buildTxList(context, ref, 'purchase'),
          _buildTxList(context, ref, 'credit_payment|credit_note'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            showDialog(
                context: context, builder: (ctx) => const AddSaleDialog());
          } else if (_tabController.index == 1) {
            showDialog(
                context: context, builder: (ctx) => const AddPurchaseDialog());
          } else {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.note_alt_rounded,
                            color: Colors.purple),
                      ),
                      title: const Text('Credit Note'),
                      subtitle: const Text('Record a credit note adjustment'),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                            context: context,
                            builder: (ctx) => const AddReturnDialog());
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payment_rounded,
                            color: AppColors.info),
                      ),
                      title: const Text('Credit Payment to Agency'),
                      subtitle: const Text('Pay outstanding credit amount'),
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                            context: context,
                            builder: (ctx) => const AddCreditPaymentDialog());
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0
            ? 'Add Sale'
            : _tabController.index == 1
                ? 'Add Purchase'
                : 'Options'),
      ),
    );
  }

  Widget _buildTxList(BuildContext context, WidgetRef ref, String filterType) {
    final asyncTxs = ref.watch(transactionsProvider);
    final bool isPurchaseTab = filterType == 'purchase';
    final bool hasSearch = _searchQuery.trim().isNotEmpty;

    return asyncTxs.when(
      data: (txs) {
        final filters = filterType.split('|');
        var filtered = txs
            .where((tx) {
              for (var f in filters) {
                if (tx.type.contains(f)) return true;
              }
              return false;
            })
            .where((tx) => isWithinRange(_filterDateFor(tx)))
            .toList();

        if (hasSearch) {
          filtered = filtered.where(_matchesTransactionSearch).toList();
        }

        if (isPurchaseTab) {
          filtered.sort(_comparePurchasesByBillDateDesc);
        }

        final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
        final fmtDate = DateFormat('EEE, MMM dd, yyyy');

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: _searchHintFor(filterType),
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary, size: 20),
                  suffixIcon: hasSearch
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
            ),

            // ─── Results count ───
            if (hasSearch || dateRange != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} result(s) found',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),

            // ─── List or Empty ───
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        hasSearch
                            ? 'No matching transactions'
                            : 'No transactions yet',
                        style: GoogleFonts.inter(
                            fontSize: 16, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final tx = filtered[idx];

                    Color accentColor;
                    IconData txIcon;
                    String txLabel;

                    if (tx.type == 'sale') {
                      accentColor = AppColors.success;
                      txIcon = Icons.trending_up_rounded;
                      txLabel = 'SALE';
                    } else if (tx.type == 'purchase_cash') {
                      accentColor = AppColors.warning;
                      txIcon = Icons.shopping_cart_rounded;
                      txLabel = 'CASH PURCHASE';
                    } else if (tx.type == 'purchase_credit') {
                      accentColor = Colors.deepOrange;
                      txIcon = Icons.credit_card_rounded;
                      txLabel = 'CREDIT PURCHASE';
                    } else if (tx.type == 'credit_payment') {
                      accentColor = AppColors.info;
                      txIcon = Icons.payment_rounded;
                      txLabel = 'CREDIT PAYMENT';
                    } else {
                      accentColor = Colors.purple;
                      txIcon = Icons.keyboard_return_rounded;
                      txLabel = tx.type.toUpperCase().replaceAll('_', ' ');
                    }

                    final card = Container(
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
                            offset: const Offset(0, 2),
                          ),
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
                              child: Icon(txIcon, color: accentColor, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: tx.type.startsWith('purchase')
                                  // ─── Purchase Layout ───
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Agency Name (title)
                                        Text(
                                          tx.agencyName ?? 'Unknown Agency',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        // Invoice Date (bill date)
                                        Row(
                                          children: [
                                            Text('Invoice Date : ',
                                                style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            Text(
                                              tx.billDate != null
                                                  ? fmtDate.format(
                                                      DateTime.parse(
                                                          tx.billDate!))
                                                  : '-',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        // Invoice No (bill no)
                                        Row(
                                          children: [
                                            Text('Invoice No : ',
                                                style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            Text(
                                              tx.billNo ?? '-',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Type + Amount
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: accentColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$txLabel : ${fmt.format(tx.totalAmount)}',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: accentColor,
                                                ),
                                              ),
                                            ),
                                            // Payment status badge for credit purchases
                                            if (tx.type ==
                                                'purchase_credit') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: tx.isPaid
                                                      ? AppColors.success
                                                          .withOpacity(0.1)
                                                      : tx.paidAmount > 0
                                                          ? AppColors.warning
                                                              .withOpacity(0.1)
                                                          : AppColors.danger
                                                              .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  tx.isPaid
                                                      ? '✓ PAID'
                                                      : tx.paidAmount > 0
                                                          ? '₹${tx.remainingAmount.toStringAsFixed(0)} remaining'
                                                          : 'UNPAID',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: tx.isPaid
                                                        ? AppColors.success
                                                        : tx.paidAmount > 0
                                                            ? AppColors.warning
                                                            : AppColors.danger,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    )
                                  // ─── Default Layout (Sales, Returns, etc.) ───
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: accentColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                txLabel,
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
                                              fmtDate.format(
                                                  DateTime.parse(tx.date)),
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          fmt.format(tx.totalAmount),
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (tx.agencyName != null &&
                                            tx.agencyName!.isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              tx.agencyName!,
                                              style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _IconAction(
                                  icon: Icons.edit_rounded,
                                  color: AppColors.info,
                                  onTap: () {
                                    if (tx.type == 'sale') {
                                      showDialog(
                                          context: context,
                                          builder: (ctx) =>
                                              AddSaleDialog(existingTx: tx));
                                    } else if (tx.type.startsWith('purchase')) {
                                      showDialog(
                                          context: context,
                                          builder: (ctx) => AddPurchaseDialog(
                                              existingTx: tx));
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                _IconAction(
                                  icon: Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                  onTap: () => _confirmDeleteTransaction(tx),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                    if (tx.type == 'purchase_credit') {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPaymentHistorySheet(context, tx),
                          borderRadius: BorderRadius.circular(14),
                          child: card,
                        ),
                      );
                    }
                    return card;
                  },
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _HistorySummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _HistorySummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color.withOpacity(0.7)),
        ),
      ),
    );
  }
}
