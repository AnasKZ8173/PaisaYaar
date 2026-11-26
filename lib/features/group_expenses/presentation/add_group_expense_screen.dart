import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/finance/split_calculator_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/data/group_models.dart';
import '../../groups/providers/groups_provider.dart';
import '../../personal_finance/data/personal_finance_repository.dart';
import '../../personal_finance/providers/personal_finance_provider.dart';
import '../data/group_expense_models.dart';
import '../data/group_expense_repository.dart';
import '../providers/group_expenses_provider.dart';

class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  const AddGroupExpenseScreen({
    super.key,
    required this.groupId,
    this.editingExpense,
  });

  final String groupId;
  final GroupExpenseModel? editingExpense;

  @override
  ConsumerState<AddGroupExpenseScreen> createState() =>
      _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends ConsumerState<AddGroupExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _category = 'Food';
  String _paymentMethod = 'cash';
  String _splitMethod = 'equal'; // equal | exact
  bool _initializedMembers = false;
  bool _saving = false;
  bool _deductFromPersonalAccount = false;
  String? _selectedPersonalAccountId;
  String? _error;

  final Map<String, TextEditingController> _payerCtrls = {};
  final Set<String> _selectedPayers = {};
  final Set<String> _selectedParticipants = {};
  final Map<String, TextEditingController> _exactShareCtrls = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    for (final c in _payerCtrls.values) {
      c.dispose();
    }
    for (final c in _exactShareCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initMembers(List<GroupMemberModel> members) {
    if (_initializedMembers || members.isEmpty) return;
    _initializedMembers = true;
    final editing = widget.editingExpense;
    final currentUid = ref.read(currentUserProvider)?.id ?? members.first.userId;
    for (final m in members) {
      _payerCtrls[m.userId] = TextEditingController();
      _exactShareCtrls[m.userId] = TextEditingController();
      if (editing == null) {
        _selectedParticipants.add(m.userId);
      }
    }
    if (editing != null) {
      _titleCtrl.text = editing.title;
      _descCtrl.text = editing.description;
      _amountCtrl.text = (editing.totalAmountMinor / 100).toStringAsFixed(0);
      _category = editing.category;
      _paymentMethod = editing.paymentMethod;
      _splitMethod = editing.splitMethod == 'exact' ? 'exact' : 'equal';
      for (final p in editing.payers) {
        _selectedPayers.add(p.userId);
        _payerCtrls[p.userId]?.text =
            (p.paidAmountMinor / 100).toStringAsFixed(0);
      }
      for (final s in editing.participants) {
        _selectedParticipants.add(s.userId);
        _exactShareCtrls[s.userId]?.text =
            (s.shareAmountMinor / 100).toStringAsFixed(0);
      }
    } else {
      _selectedPayers.add(currentUid);
    }
  }

  int get _totalMinor {
    final major = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    return (major * 100).round();
  }

  Future<void> _submit(List<GroupMemberModel> members) async {
    if (!_formKey.currentState!.validate()) return;
    final total = _totalMinor;
    if (total <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }

    // Build payers
    final payerMap = <String, int>{};
    if (_selectedPayers.length == 1) {
      payerMap[_selectedPayers.first] = total;
    } else {
      for (final uid in _selectedPayers) {
        final major = double.tryParse(_payerCtrls[uid]?.text.trim() ?? '') ?? 0;
        final minor = (major * 100).round();
        if (minor > 0) payerMap[uid] = minor;
      }
    }

    final payerErr = SplitCalculatorService.validatePayers(
      totalMinor: total,
      payerAmountsMinor: payerMap,
    );
    if (payerErr != null) {
      setState(() => _error = payerErr);
      return;
    }

    // Build participant shares
    final Map<String, int> shareMap;
    if (_splitMethod == 'equal') {
      if (_selectedParticipants.isEmpty) {
        setState(() => _error = 'Select at least one participant');
        return;
      }
      shareMap = SplitCalculatorService.calculateEqualSplit(
        totalMinor: total,
        participantUserIds: _selectedParticipants.toList(),
      );
    } else {
      shareMap = {};
      for (final uid in _selectedParticipants) {
        final major =
            double.tryParse(_exactShareCtrls[uid]?.text.trim() ?? '') ?? 0;
        shareMap[uid] = (major * 100).round();
      }
      final splitErr = SplitCalculatorService.validateExactSplit(
        totalMinor: total,
        exactSharesMinor: shareMap,
      );
      if (splitErr != null) {
        setState(() => _error = splitErr);
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final editing = widget.editingExpense;
      if (editing != null) {
        await ref.read(groupExpenseRepositoryProvider).updateExpense(
              expenseId: editing.id,
              title: _titleCtrl.text,
              description: _descCtrl.text,
              totalAmountMinor: total,
              category: _category,
              splitMethod: _splitMethod,
              paymentMethod: _paymentMethod,
              payers: payerMap.entries
                  .map(
                    (e) => ExpensePayerModel(
                      userId: e.key,
                      paidAmountMinor: e.value,
                    ),
                  )
                  .toList(),
              participants: shareMap.entries
                  .map(
                    (e) => ExpenseParticipantModel(
                      userId: e.key,
                      shareAmountMinor: e.value,
                    ),
                  )
                  .toList(),
            );
      } else {
        final expenseId =
            await ref.read(groupExpenseRepositoryProvider).createExpense(
              groupId: widget.groupId,
              title: _titleCtrl.text,
              description: _descCtrl.text,
              totalAmountMinor: total,
              category: _category,
              expenseDate: DateTime.now(),
              splitMethod: _splitMethod,
              paymentMethod: _paymentMethod,
              payers: payerMap.entries
                  .map(
                    (e) => ExpensePayerModel(
                      userId: e.key,
                      paidAmountMinor: e.value,
                    ),
                  )
                  .toList(),
              participants: shareMap.entries
                  .map(
                    (e) => ExpenseParticipantModel(
                      userId: e.key,
                      shareAmountMinor: e.value,
                    ),
                  )
                  .toList(),
            );

        final uid = ref.read(currentUserProvider)?.id;
        final myPaidMinor = uid != null ? (payerMap[uid] ?? 0) : 0;
        if (_deductFromPersonalAccount &&
            _selectedPersonalAccountId != null &&
            myPaidMinor > 0) {
          await ref.read(personalFinanceRepositoryProvider).recordTransaction(
                accountId: _selectedPersonalAccountId!,
                txType: 'group_payment',
                amountMinor: myPaidMinor,
                title: 'Group: ${_titleCtrl.text.trim()}',
                paymentMethod: _paymentMethod,
                linkedGroupExpenseId: expenseId,
              );
          ref.invalidate(personalAccountsProvider);
          ref.invalidate(personalTransactionsProvider);
        }
      }

      ref.invalidate(groupExpensesProvider(widget.groupId));
      ref.invalidate(groupActivityProvider(widget.groupId));
      ref.invalidate(groupDashboardSummaryProvider);
      ref.invalidate(myGroupExpenseSharesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingExpense != null
              ? 'Edit Group Expense'
              : 'Add Group Expense',
        ),
      ),
      body: membersAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorState(message: e.toString()),
        data: (members) {
          _initMembers(members);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _titleCtrl,
                        label: 'Expense title',
                        hint: 'e.g. Dinner at Monal',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _amountCtrl,
                        label: 'Total amount',
                        hint: '10000',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _category,
                              decoration:
                                  const InputDecoration(labelText: 'Category'),
                              items: const [
                                'Food',
                                'Transport',
                                'Shopping',
                                'Bills',
                                'Home',
                                'Other',
                              ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _category = v);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              decoration:
                                  const InputDecoration(labelText: 'Method'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'bank',
                                  child: Text('Bank'),
                                ),
                                DropdownMenuItem(
                                  value: 'easypaisa',
                                  child: Text('Easypaisa'),
                                ),
                                DropdownMenuItem(
                                  value: 'jazzcash',
                                  child: Text('JazzCash'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _paymentMethod = v;
                                    _deductFromPersonalAccount = v != 'cash';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Payers
                Text(
                  'Who Paid?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: members.map((m) {
                      final selected = _selectedPayers.contains(m.userId);
                      return Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.fullName),
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedPayers.add(m.userId);
                                } else if (_selectedPayers.length > 1) {
                                  _selectedPayers.remove(m.userId);
                                }
                              });
                            },
                          ),
                          if (selected && _selectedPayers.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: TextField(
                                controller: _payerCtrls[m.userId],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '${m.fullName} paid amount',
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Split Method & Participants
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Split Among',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'equal', label: Text('Equal')),
                        ButtonSegment(value: 'exact', label: Text('Exact')),
                      ],
                      selected: {_splitMethod},
                      onSelectionChanged: (sel) =>
                          setState(() => _splitMethod = sel.first),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    children: members.map((m) {
                      final selected = _selectedParticipants.contains(m.userId);
                      final equalPreview = (_splitMethod == 'equal' &&
                              selected &&
                              _totalMinor > 0 &&
                              _selectedParticipants.isNotEmpty)
                          ? SplitCalculatorService.calculateEqualSplit(
                              totalMinor: _totalMinor,
                              participantUserIds:
                                  _selectedParticipants.toList(),
                            )[m.userId]
                          : null;

                      return Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.fullName),
                            subtitle: equalPreview != null
                                ? Text(
                                    'Share: ${(equalPreview / 100).toStringAsFixed(2)}',
                                  )
                                : null,
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedParticipants.add(m.userId);
                                } else {
                                  _selectedParticipants.remove(m.userId);
                                }
                              });
                            },
                          ),
                          if (selected && _splitMethod == 'exact')
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: TextField(
                                controller: _exactShareCtrls[m.userId],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '${m.fullName} exact share',
                                ),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                Builder(
                  builder: (context) {
                    final personalAccounts =
                        ref.watch(personalAccountsProvider).valueOrNull ??
                            const [];
                    if (personalAccounts.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    _selectedPersonalAccountId ??= personalAccounts.first.id;
                    return AppCard(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Deduct my payment from personal account',
                            ),
                            value: _deductFromPersonalAccount,
                            onChanged: (v) => setState(
                              () => _deductFromPersonalAccount = v,
                            ),
                          ),
                          if (_deductFromPersonalAccount)
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPersonalAccountId,
                              decoration: const InputDecoration(
                                labelText: 'Personal account',
                              ),
                              items: personalAccounts
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => _selectedPersonalAccountId = v,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.negativeRed),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save Group Expense',
                  isLoading: _saving,
                  onPressed: () => _submit(members),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
