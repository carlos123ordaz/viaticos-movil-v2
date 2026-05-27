import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/expense_card.dart';

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
      final found =
          provider.expenses.where((e) => e.id == widget.expenseId).firstOrNull;
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
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gasto eliminado')));
    }
  }

  bool _hasDesglose(ExpenseModel e) =>
      e.igv > 0 ||
      (e.discount != null && e.discount! > 0) ||
      (e.detraction != null && e.detraction! > 0);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _expense == null) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(title: const Text('Detalle')),
        body: Center(
            child: Text(_error ?? 'Gasto no encontrado',
                style: const TextStyle(color: AppTheme.error))),
      );
    }

    final expense = _expense!;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: getCategoryColor(expense.category),
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroSection(expense: expense),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AmountHeader(expense: expense),
                  const SizedBox(height: 20),
                  _InfoCard(expense: expense),
                  if (expense.taskName != null) ...[
                    const SizedBox(height: 16),
                    _TaskCard(taskId: expense.taskId, taskName: expense.taskName!),
                  ],
                  if (_hasDesglose(expense)) ...[
                    const SizedBox(height: 16),
                    _DesglosCard(expense: expense),
                  ],
                  if (expense.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ItemsCard(expense: expense),
                  ],
                  if (expense.costCenterAllocations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _CostCentersCard(expense: expense),
                  ],
                  if (expense.descrip != null && expense.descrip!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _DescripCard(descrip: expense.descrip!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        onDelete: _delete,
        onEdit: () => context.push('/edit-expense/${expense.id}'),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final ExpenseModel expense;
  const _HeroSection({required this.expense});

  @override
  Widget build(BuildContext context) {
    final catColor = getCategoryColor(expense.category);
    final catIcon = getCategoryIcon(expense.category);
    final (statusColor, statusBg, statusLabel) = _statusInfo(expense.status);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [catColor, Color.lerp(catColor, AppTheme.ink, 0.28)!],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Status pill
          Positioned(
            top: 56,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ),
          // Category icon + label
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, size: 38, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (expense.categoryName ?? expense.category.label)
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Amount header ─────────────────────────────────────────────────────────────

class _AmountHeader extends StatelessWidget {
  final ExpenseModel expense;
  const _AmountHeader({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final vendorName = expense.businessName ?? expense.category.label;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vendorName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(expense.amount, currency: expense.currency),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final ExpenseModel expense;
  const _InfoCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final rows = <_RowData>[
      _RowData(Icons.calendar_today_rounded, 'Fecha',
          Formatters.date(expense.date)),
      if (expense.type != null)
        _RowData(Icons.swap_horiz_rounded, 'Tipo',
            expense.type == 'viatico' ? 'Viático' : 'Compra'),
      _RowData(Icons.category_rounded, 'Categoría',
          expense.categoryName ?? expense.category.label),
      if (expense.documentType != null)
        _RowData(Icons.description_outlined, 'Tipo documento',
            expense.documentType!),
      if (expense.receiptNumber != null)
        _RowData(Icons.confirmation_number_outlined, 'Comprobante',
            expense.receiptNumber!),
      if (expense.ruc != null)
        _RowData(Icons.numbers_rounded, 'RUC', expense.ruc!),
      if (expense.address != null)
        _RowData(Icons.location_on_outlined, 'Dirección', expense.address!),
      if (expense.receiptDetail != null)
        _RowData(Icons.article_outlined, 'Tipo de sustento',
            expense.receiptDetail!),
    ];

    return _ShadowCard(
      child: Column(
        children: List.generate(rows.length, (i) {
          return Column(
            children: [
              _InfoRow(data: rows[i]),
              if (i < rows.length - 1)
                Divider(height: 1, thickness: 1, color: c.line),
            ],
          );
        }),
      ),
    );
  }
}

class _RowData {
  final IconData icon;
  final String label;
  final String value;
  const _RowData(this.icon, this.label, this.value);
}

class _InfoRow extends StatelessWidget {
  final _RowData data;
  const _InfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.surfaceTinted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 16, color: c.muted),
          ),
          const SizedBox(width: 12),
          Text(data.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.muted)),
          const Spacer(),
          Flexible(
            child: Text(data.value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink2)),
          ),
        ],
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final String? taskId;
  final String taskName;
  const _TaskCard({this.taskId, required this.taskName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.task_alt_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (taskId != null)
                  Text('Tarea #$taskId',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                Text(taskName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desglose card ─────────────────────────────────────────────────────────────

class _DesglosCard extends StatelessWidget {
  final ExpenseModel expense;
  const _DesglosCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final subtotal = expense.amount - expense.igv;
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Desglose',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink)),
            const SizedBox(height: 12),
            _DesglosRow('Subtotal',
                Formatters.currency(subtotal, currency: expense.currency)),
            if (expense.igv > 0) ...[
              const SizedBox(height: 8),
              _DesglosRow('IGV (18%)',
                  Formatters.currency(expense.igv, currency: expense.currency)),
            ],
            if (expense.discount != null && expense.discount! > 0) ...[
              const SizedBox(height: 8),
              _DesglosRow(
                  'Descuento',
                  '−${Formatters.currency(expense.discount!, currency: expense.currency)}',
                  valueColor: AppTheme.secondary),
            ],
            if (expense.detraction != null && expense.detraction! > 0) ...[
              const SizedBox(height: 8),
              _DesglosRow(
                  'Detracción',
                  '−${Formatters.currency(expense.detraction!, currency: expense.currency)}',
                  valueColor: AppTheme.secondary),
            ],
            const SizedBox(height: 12),
            const _DashedDivider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
                Text(
                  Formatters.currency(expense.amount, currency: expense.currency),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesglosRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DesglosRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: c.muted)),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? c.muted)),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final lineColor = context.appColors.line;
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
      return Row(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.only(right: dashSpace),
            child: Container(width: dashWidth, height: 1.5, color: lineColor),
          ),
        ),
      );
    });
  }
}

// ── Items card ────────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  final ExpenseModel expense;
  const _ItemsCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalle del comprobante',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink)),
            const SizedBox(height: 12),
            ...expense.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.descrip,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.ink2)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Formatters.currency(item.subtotal,
                          currency: expense.currency),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cost centers card ─────────────────────────────────────────────────────────

class _CostCentersCard extends StatelessWidget {
  final ExpenseModel expense;
  const _CostCentersCard({required this.expense});

  static const _barColors = [
    AppTheme.primary,
    AppTheme.mint,
    AppTheme.coral,
    AppTheme.violet,
    AppTheme.sky,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Centros de costo',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink)),
            const SizedBox(height: 12),
            ...expense.costCenterAllocations.asMap().entries.map((entry) {
              final barColor = _barColors[entry.key % _barColors.length];
              final alloc = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(alloc.costCenterName ?? '—',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.ink)),
                        ),
                        Text(
                          '${alloc.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: barColor),
                        ),
                      ],
                    ),
                    if (alloc.subCostCenterName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(alloc.subCostCenterName!,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.muted)),
                      )
                    else
                      const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: alloc.percentage / 100,
                        minHeight: 6,
                        backgroundColor: c.surfaceTinted,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Description card ──────────────────────────────────────────────────────────

class _DescripCard extends StatelessWidget {
  final String descrip;
  const _DescripCard({required this.descrip});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descripción',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.ink)),
            const SizedBox(height: 8),
            Text(descrip,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.ink2,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _BottomBar({required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: AppTheme.error, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Eliminar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: onEdit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Editar gasto',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared shadow card ────────────────────────────────────────────────────────

class _ShadowCard extends StatelessWidget {
  final Widget child;
  const _ShadowCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ── Status helper ─────────────────────────────────────────────────────────────

(Color, Color, String) _statusInfo(String status) {
  switch (status.toLowerCase()) {
    case 'approved':
    case 'aprobado':
      return (AppTheme.secondary, AppTheme.secondaryContainer, 'Aprobado');
    case 'rejected':
    case 'rechazado':
      return (AppTheme.error, AppTheme.errorContainer, 'Rechazado');
    default:
      return (AppTheme.warn, AppTheme.warnTint, 'Pendiente');
  }
}
