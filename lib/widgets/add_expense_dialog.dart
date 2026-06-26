import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../main.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  final Expense? existingExpense;
  const AddExpenseDialog({super.key, this.existingExpense});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _subcategoryCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _classFocusNode = FocusNode();
  final _itemFocusNode = FocusNode();
  ExpenseCategory? _selectedCategory;
  List<String> _classOptions = [];
  List<String> _itemOptions = [];
  int? _loadingClassCategoryId;
  int? _loadedClassCategoryId;
  String? _loadingItemKey;
  String? _loadedItemKey;
  String _paymentMethod = 'cash';
  DateTime _entryDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      _amountCtrl.text = widget.existingExpense!.amount.toString();
      _subcategoryCtrl.text = widget.existingExpense!.subcategory ?? '';
      _itemCtrl.text = widget.existingExpense!.item ?? '';
      _paymentMethod = widget.existingExpense!.paymentMethod ?? 'cash';
      _noteCtrl.text = widget.existingExpense!.note ?? '';
      try {
        _entryDate = DateTime.parse(widget.existingExpense!.date);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _subcategoryCtrl.dispose();
    _itemCtrl.dispose();
    _noteCtrl.dispose();
    _classFocusNode.dispose();
    _itemFocusNode.dispose();
    super.dispose();
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;
    setState(() => _isSaving = true);

    final expense = Expense(
      id: widget.existingExpense?.id,
      categoryId: _selectedCategory!.id!,
      amount: double.parse(_amountCtrl.text),
      date: _entryDate.toIso8601String(),
      subcategory: _subcategoryCtrl.text.trim().isNotEmpty
          ? _subcategoryCtrl.text.trim()
          : null,
      item: _itemCtrl.text.trim().isNotEmpty ? _itemCtrl.text.trim() : null,
      paymentMethod: _paymentMethod,
      note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
    );

    if (widget.existingExpense != null) {
      await ref.read(expensesProvider.notifier).updateExpense(expense);
    } else {
      await ref.read(expensesProvider.notifier).addExpense(expense);
    }
    if (mounted) Navigator.of(context).pop();
  }

  List<String> _uniqueSortedValues(Iterable<String?> rawValues) {
    final byLowercase = <String, String>{};
    for (final rawValue in rawValues) {
      final value = rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        byLowercase.putIfAbsent(value.toLowerCase(), () => value);
      }
    }
    final values = byLowercase.values.toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String>? _cachedClassesForCategory(int categoryId) {
    final expenses = ref.read(expensesProvider).valueOrNull;
    if (expenses == null) return null;
    return _uniqueSortedValues(
      expenses
          .where((expense) => expense.categoryId == categoryId)
          .map((expense) => expense.subcategory),
    );
  }

  List<String>? _cachedItemsForSelection(int categoryId, String expenseClass) {
    final expenses = ref.read(expensesProvider).valueOrNull;
    if (expenses == null) return null;
    final normalizedClass = expenseClass.trim().toLowerCase();
    return _uniqueSortedValues(
      expenses.where((expense) {
        if (expense.categoryId != categoryId) return false;
        final candidateClass = (expense.subcategory ?? '').trim().toLowerCase();
        return candidateClass == normalizedClass;
      }).map((expense) => expense.item),
    );
  }

  void _focusClassFieldAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _classFocusNode.requestFocus();
    });
  }

  void _focusItemFieldAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _itemFocusNode.requestFocus();
    });
  }

  Future<void> _loadClassesForCategory(
    ExpenseCategory? category, {
    bool clearCurrentClass = false,
    bool focusClassField = false,
  }) async {
    final categoryId = category?.id;
    if (categoryId == null) {
      if (!mounted) return;
      setState(() {
        _classOptions = [];
        _loadingClassCategoryId = null;
        _loadedClassCategoryId = null;
        if (clearCurrentClass) _subcategoryCtrl.clear();
      });
      return;
    }

    setState(() {
      _classOptions = [];
      _loadingClassCategoryId = categoryId;
      _loadedClassCategoryId = null;
      if (clearCurrentClass) _subcategoryCtrl.clear();
    });

    final cachedClasses = _cachedClassesForCategory(categoryId);
    if (cachedClasses != null && cachedClasses.isNotEmpty) {
      setState(() {
        _classOptions = cachedClasses;
        _loadingClassCategoryId = null;
        _loadedClassCategoryId = categoryId;
      });
      if (focusClassField) _focusClassFieldAfterFrame();
      return;
    }

    final classes = await ExpenseRepository.getClassesForCategory(categoryId);
    if (!mounted || _selectedCategory?.id != categoryId) return;
    setState(() {
      _classOptions = classes.isNotEmpty ? classes : cachedClasses ?? [];
      _loadingClassCategoryId = null;
      _loadedClassCategoryId = categoryId;
    });
    if (focusClassField) _focusClassFieldAfterFrame();
  }

  String _itemOptionKey(int categoryId, String expenseClass) {
    return '$categoryId|${expenseClass.trim().toLowerCase()}';
  }

  Future<void> _loadItemsForSelection({
    bool clearCurrentItem = false,
    bool focusItemField = false,
  }) async {
    final categoryId = _selectedCategory?.id;
    if (categoryId == null) {
      if (!mounted) return;
      setState(() {
        _itemOptions = [];
        _loadingItemKey = null;
        _loadedItemKey = null;
        if (clearCurrentItem) _itemCtrl.clear();
      });
      return;
    }

    final currentClass = _subcategoryCtrl.text.trim();
    final optionKey = _itemOptionKey(categoryId, currentClass);
    setState(() {
      _itemOptions = [];
      _loadingItemKey = optionKey;
      _loadedItemKey = null;
      if (clearCurrentItem) _itemCtrl.clear();
    });

    final cachedItems = _cachedItemsForSelection(categoryId, currentClass);
    if (cachedItems != null && cachedItems.isNotEmpty) {
      setState(() {
        _itemOptions = cachedItems;
        _loadingItemKey = null;
        _loadedItemKey = optionKey;
      });
      if (focusItemField) _focusItemFieldAfterFrame();
      return;
    }

    final items = await ExpenseRepository.getItemsForCategoryClass(
      categoryId: categoryId,
      expenseClass: currentClass,
    );
    if (!mounted ||
        _selectedCategory?.id != categoryId ||
        _itemOptionKey(categoryId, _subcategoryCtrl.text) != optionKey) {
      return;
    }
    setState(() {
      _itemOptions = items.isNotEmpty ? items : cachedItems ?? [];
      _loadingItemKey = null;
      _loadedItemKey = optionKey;
    });
    if (focusItemField) _focusItemFieldAfterFrame();
  }

  void _scheduleItemOptionsLoad() {
    final categoryId = _selectedCategory?.id;
    if (categoryId == null) return;
    final optionKey = _itemOptionKey(categoryId, _subcategoryCtrl.text);
    if (_loadedItemKey == optionKey || _loadingItemKey == optionKey) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItemsForSelection();
    });
  }

  void _onClassChanged(String value) {
    final categoryId = _selectedCategory?.id;
    if (categoryId == null) return;
    final optionKey = _itemOptionKey(categoryId, value);
    if (_loadedItemKey == optionKey || _loadingItemKey == optionKey) return;
    _loadItemsForSelection(clearCurrentItem: true);
  }

  void _onClassSelected(String value) {
    _subcategoryCtrl.text = value;
    _loadItemsForSelection(clearCurrentItem: true, focusItemField: true);
  }

  void _onCategoryChanged(ExpenseCategory? category) {
    setState(() => _selectedCategory = category);
    setState(() {
      _itemOptions = [];
      _loadingItemKey = null;
      _loadedItemKey = null;
      _itemCtrl.clear();
    });
    _loadClassesForCategory(
      category,
      clearCurrentClass: true,
      focusClassField: true,
    );
    _loadItemsForSelection(clearCurrentItem: true);
  }

  void _scheduleClassOptionsLoad(ExpenseCategory? category) {
    final categoryId = category?.id;
    if (categoryId == null ||
        _loadedClassCategoryId == categoryId ||
        _loadingClassCategoryId == categoryId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassesForCategory(category);
    });
  }

  void _addCustomCategory() async {
    final newCategoryName = await _showAddCategoryDialog(context);
    if (newCategoryName != null && newCategoryName.isNotEmpty) {
      final newCat = await CategoryRepository.addCategory(newCategoryName);
      ref.invalidate(expenseCategoriesProvider);
      ref.invalidate(allExpenseCategoriesProvider);
      setState(() => _selectedCategory = newCat);
      await _loadClassesForCategory(newCat, clearCurrentClass: true);
      await _loadItemsForSelection(clearCurrentItem: true);
    }
  }

  Future<void> _deleteSelectedCategory() async {
    final category = _selectedCategory;
    if (category?.id == null) return;
    final categoryId = category!.id!;
    final categoryName = category.name;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Remove "$categoryName" from future expense entries?\n\n'
          'If it is already used, old expenses will keep this category name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await CategoryRepository.deleteCategory(categoryId);
    ref.invalidate(expenseCategoriesProvider);
    ref.invalidate(allExpenseCategoriesProvider);
    if (!mounted) return;

    setState(() {
      _selectedCategory = null;
      _classOptions = [];
      _loadingClassCategoryId = null;
      _loadedClassCategoryId = null;
      _subcategoryCtrl.clear();
      _itemOptions = [];
      _loadingItemKey = null;
      _loadedItemKey = null;
      _itemCtrl.clear();
    });

    final message = result == CategoryDeleteResult.deleted
        ? 'Category deleted.'
        : 'Category hidden from future entries. Old expenses are unchanged.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _showAddCategoryDialog(BuildContext context) {
    final actrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Category',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                  controller: actrl,
                  decoration:
                      const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(actrl.text),
                      child: const Text('Add')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

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
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: AppColors.danger, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                          widget.existingExpense != null
                              ? 'Edit Expense'
                              : 'Add Expense',
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

                  // Date
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

                  // Category
                  categoriesAsync.when(
                    data: (categories) {
                      if (_selectedCategory == null &&
                          widget.existingExpense != null) {
                        try {
                          _selectedCategory = categories.firstWhere((c) =>
                              c.id == widget.existingExpense!.categoryId);
                          _scheduleClassOptionsLoad(_selectedCategory);
                        } catch (_) {}
                      }
                      _scheduleClassOptionsLoad(_selectedCategory);
                      _scheduleItemOptionsLoad();
                      return DropdownButtonFormField<ExpenseCategory>(
                        value: _selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        hint: const Text('Choose Category'),
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)))
                            .toList(),
                        onChanged: _onCategoryChanged,
                        validator: (val) => val == null ? 'Required' : null,
                      );
                    },
                    loading: () => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator())),
                    error: (err, stack) => Text('Error: $err'),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _addCustomCategory,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Custom Category'),
                      ),
                      const Spacer(),
                      if (_selectedCategory != null)
                        TextButton.icon(
                          onPressed: _deleteSelectedCategory,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text('Delete Category'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  RawAutocomplete<String>(
                    key: ValueKey(
                      'class-${_selectedCategory?.id ?? 'none'}-${_classOptions.join('|')}',
                    ),
                    textEditingController: _subcategoryCtrl,
                    focusNode: _classFocusNode,
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) return _classOptions;
                      return _classOptions.where(
                        (option) => option.toLowerCase().contains(query),
                      );
                    },
                    onSelected: _onClassSelected,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Class',
                          hintText: _selectedCategory == null
                              ? 'Choose category first'
                              : _classOptions.isEmpty
                                  ? 'Optional'
                                  : 'Choose or type class',
                          suffixIcon: _classOptions.isEmpty
                              ? null
                              : const Icon(Icons.arrow_drop_down_rounded),
                        ),
                        onChanged: _onClassChanged,
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight: 220,
                              maxWidth: 400,
                            ),
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
                                final option = options.elementAt(idx);
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.label_outline_rounded,
                                    color: AppColors.accent,
                                    size: 18,
                                  ),
                                  title: Text(
                                    option,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  RawAutocomplete<String>(
                    key: ValueKey(
                      'item-${_selectedCategory?.id ?? 'none'}-${_subcategoryCtrl.text.trim().toLowerCase()}-${_itemOptions.join('|')}',
                    ),
                    textEditingController: _itemCtrl,
                    focusNode: _itemFocusNode,
                    optionsBuilder: (textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) return _itemOptions;
                      return _itemOptions.where(
                        (option) => option.toLowerCase().contains(query),
                      );
                    },
                    onSelected: (value) => _itemCtrl.text = value,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Item',
                          hintText: _selectedCategory == null
                              ? 'Choose category first'
                              : _itemOptions.isEmpty
                                  ? 'Optional'
                                  : 'Choose or type item',
                          suffixIcon: _itemOptions.isEmpty
                              ? null
                              : const Icon(Icons.arrow_drop_down_rounded),
                        ),
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight: 220,
                              maxWidth: 400,
                            ),
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
                                final option = options.elementAt(idx);
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.accent,
                                    size: 18,
                                  ),
                                  title: Text(
                                    option,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
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
                          double.parse(val) <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Payment',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'cash',
                        icon: Icon(Icons.payments_rounded),
                        label: Text('Cash'),
                      ),
                      ButtonSegment<String>(
                        value: 'other',
                        icon: Icon(Icons.more_horiz_rounded),
                        label: Text('Other'),
                      ),
                    ],
                    selected: {_paymentMethod},
                    onSelectionChanged: (values) {
                      setState(() => _paymentMethod = values.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(labelText: 'Comments'),
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
                        onPressed: _isSaving ? null : _saveExpense,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(widget.existingExpense != null
                            ? 'Update'
                            : 'Save Expense'),
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
