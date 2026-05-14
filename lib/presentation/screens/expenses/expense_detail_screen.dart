import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  ExpenseModel? _expense;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final provider = context.read<ExpenseProvider>();
      final found = provider.expenses
          .where((e) => e.id == widget.expenseId)
          .firstOrNull;
      setState(() {
        _expense = found;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el gasto';
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text(
            '¿Estás seguro de que deseas eliminar este gasto? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context.read<ExpenseProvider>().delete(widget.expenseId);
    if (!mounted) return;
    if (ok) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gasto eliminado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: Center(
            child: Text(_error ?? 'Gasto no encontrado',
                style: TextStyle(color: colors.error))),
      );
    }

    final expense = _expense!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero AppBar con categoría
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              IconButton(
                onPressed: () => context.push('/edit-expense/${expense.id}'),
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(
                onPressed: _delete,
                icon: Icon(Icons.delete_outlined, color: colors.error),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ExpenseHero(expense: expense),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción y monto
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          expense.description,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.currency(expense.amount,
                                currency: expense.currency),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                ),
                          ),
                          if (expense.igv > 0)
                            Text(
                              'IGV: ${Formatters.currency(expense.igv, currency: expense.currency)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.outline),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Info Cards
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Fecha',
                    value: Formatters.date(expense.date),
                  ),
                  const Divider(height: 24),
                  if (expense.type != null) ...[
                    _InfoRow(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Tipo',
                      value: expense.type == 'viatico' ? 'Viático' : 'Compra',
                    ),
                    const Divider(height: 24),
                  ],
                  _InfoRow(
                    icon: Icons.category_rounded,
                    label: 'Categoría',
                    value: expense.categoryName ?? expense.category.label,
                  ),
                  if (expense.businessName != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.business_outlined,
                      label: 'Razón Social',
                      value: expense.businessName!,
                    ),
                  ],
                  if (expense.ruc != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.numbers_rounded,
                      label: 'RUC',
                      value: expense.ruc!,
                    ),
                  ],
                  if (expense.taskName != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.task_alt_rounded,
                      label: 'Tarea Bitrix',
                      value: expense.taskName!,
                    ),
                  ],
                  if (expense.igv > 0) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.receipt_long_rounded,
                      label: 'IGV',
                      value: Formatters.currency(expense.igv, currency: expense.currency),
                    ),
                  ],
                  if (expense.discount != null && expense.discount! > 0) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.discount_rounded,
                      label: 'Descuento',
                      value: Formatters.currency(expense.discount!, currency: expense.currency),
                    ),
                  ],
                  if (expense.detraction != null && expense.detraction! > 0) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.money_off_rounded,
                      label: 'Detracción',
                      value: Formatters.currency(expense.detraction!, currency: expense.currency),
                    ),
                  ],
                  if (expense.receiptDetail != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.article_outlined,
                      label: 'Tipo de sustento',
                      value: expense.receiptDetail!,
                    ),
                  ],
                  if (expense.documentType != null) ...[
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.description_outlined,
                      label: 'Tipo de documento',
                      value: expense.documentType!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Items del comprobante
                  if (expense.items.isNotEmpty) ...[
                    Text('Detalle del comprobante',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: expense.items
                              .map((item) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(item.descrip,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium),
                                        ),
                                        Text(
                                          Formatters.currency(item.subtotal, currency: expense.currency),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colors.primary),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  // Centros de costo
                  if (expense.costCenterAllocations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Centros de costo',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ...expense.costCenterAllocations.map(
                      (alloc) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              '${alloc.percentage.toInt()}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary),
                            ),
                          ),
                          title: Text(alloc.costCenterName ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: alloc.subCostCenterName != null
                              ? Text(alloc.subCostCenterName!)
                              : null,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseHero extends StatelessWidget {
  final ExpenseModel expense;
  const _ExpenseHero({required this.expense});

  @override
  Widget build(BuildContext context) {
    const catColors = {
      ExpenseCategory.alimentacion: [Color(0xFFD97706), Color(0xFFB45309)],
      ExpenseCategory.transporte: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      ExpenseCategory.alojamiento: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
      ExpenseCategory.compras: [Color(0xFFDB2777), Color(0xFFBE185D)],
      ExpenseCategory.otros: [Color(0xFF059669), Color(0xFF047857)],
    };
    const catIcons = {
      ExpenseCategory.alimentacion: Icons.restaurant_rounded,
      ExpenseCategory.transporte: Icons.directions_car_rounded,
      ExpenseCategory.alojamiento: Icons.hotel_rounded,
      ExpenseCategory.compras: Icons.shopping_bag_rounded,
      ExpenseCategory.otros: Icons.receipt_rounded,
    };

    final colors = catColors[expense.category] ??
        [const Color(0xFF059669), const Color(0xFF047857)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(catIcons[expense.category] ?? Icons.receipt_rounded,
              size: 44, color: Colors.white),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.outline),
        const SizedBox(width: 12),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.outline)),
        const Spacer(),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
