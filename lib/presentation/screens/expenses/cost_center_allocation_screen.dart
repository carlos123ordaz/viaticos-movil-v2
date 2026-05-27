import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/cost_center_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/cost_center_service.dart';
import '../../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';

class CostCenterAllocationScreen extends StatefulWidget {
  final List<CostCenterAllocation> initialAllocations;

  const CostCenterAllocationScreen({
    super.key,
    this.initialAllocations = const [],
  });

  @override
  State<CostCenterAllocationScreen> createState() =>
      _CostCenterAllocationScreenState();
}

class _CostCenterAllocationScreenState
    extends State<CostCenterAllocationScreen> {
  List<_AllocationRow> _rows = [];
  List<CostCenterModel> _costCenters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final service = context.read<CostCenterService>();
    final storage = context.read<StorageService>();
    try {
      final centers = await service.getCostCenters();
      List<_AllocationRow> rows;
      if (widget.initialAllocations.isNotEmpty) {
        rows = [];
        for (final a in widget.initialAllocations) {
          final pct = a.percentage;
          final pctStr = pct % 1 == 0
              ? pct.toInt().toString()
              : pct.toStringAsFixed(1);
          final row = _AllocationRow(initialPercent: pctStr);
          final cc = a.costCenterId != null
              ? centers.where((c) => c.costCenterId == a.costCenterId).firstOrNull
              : null;
          if (cc != null) {
            row.selectedCC = cc;
            if (a.subCostCenterId != null) {
              try {
                final subs = await service.getSubCostCenters(costCenterId: cc.costCenterId);
                row.subCenters = subs;
                row.selectedSCC = subs
                    .where((sub) => sub.subCostCenterId == a.subCostCenterId)
                    .firstOrNull;
                if (a.subSubCostCenterId != null && row.selectedSCC != null) {
                  try {
                    final subsubs = await service.getSubSubCostCenters(
                        subCostCenterId: row.selectedSCC!.subCostCenterId);
                    row.subSubCenters = subsubs;
                    row.selectedSSCC = subsubs
                        .where((ss) => ss.subSubCostCenterId == a.subSubCostCenterId)
                        .firstOrNull;
                  } catch (_) {}
                }
              } catch (_) {}
            }
          }
          rows.add(row);
        }
      } else {
        final saved = storage.lastAllocations;
        if (saved != null && saved.isNotEmpty) {
          rows = [];
          for (final s in saved) {
            final ccId = (s['costCenterId'] as num?)?.toInt();
            final cc = ccId != null
                ? centers.where((c) => c.costCenterId == ccId).firstOrNull
                : null;
            final pct = (s['percentage'] as num?)?.toDouble() ?? 100;
            final pctStr = pct % 1 == 0
                ? pct.toInt().toString()
                : pct.toStringAsFixed(1);
            final row = _AllocationRow(initialPercent: pctStr);
            if (cc != null) {
              row.selectedCC = cc;
              final sccId = (s['subCostCenterId'] as num?)?.toInt();
              if (sccId != null) {
                try {
                  final subs = await service.getSubCostCenters(
                      costCenterId: cc.costCenterId);
                  row.subCenters = subs;
                  row.selectedSCC =
                      subs.where((sub) => sub.subCostCenterId == sccId).firstOrNull;
                  final ssccId = (s['subSubCostCenterId'] as num?)?.toInt();
                  if (ssccId != null && row.selectedSCC != null) {
                    try {
                      final subsubs = await service.getSubSubCostCenters(
                          subCostCenterId: row.selectedSCC!.subCostCenterId);
                      row.subSubCenters = subsubs;
                      row.selectedSSCC = subsubs
                          .where((ss) => ss.subSubCostCenterId == ssccId)
                          .firstOrNull;
                    } catch (_) {}
                  }
                } catch (_) {}
              }
            }
            rows.add(row);
          }
        } else {
          final user = context.read<AuthProvider>().user;
          final userCCId = user?.costCenterId;
          final userSCCId = user?.subCostCenterId;
          if (userCCId != null) {
            final row = _AllocationRow(initialPercent: '100');
            final cc =
                centers.where((c) => c.costCenterId == userCCId).firstOrNull;
            if (cc != null) {
              row.selectedCC = cc;
              if (userSCCId != null) {
                try {
                  final subs = await service.getSubCostCenters(
                      costCenterId: cc.costCenterId);
                  row.subCenters = subs;
                  row.selectedSCC = subs
                      .where((s) => s.subCostCenterId == userSCCId)
                      .firstOrNull;
                } catch (_) {}
              }
            }
            rows = [row];
          } else {
            rows = [_AllocationRow()];
          }
        }
      }
      setState(() {
        _costCenters = centers;
        _loading = false;
        _rows = rows;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _totalPercent =>
      _rows.fold(0, (s, r) => s + (double.tryParse(r.percentCtrl.text) ?? 0));

  bool get _isValid {
    if (_rows.isEmpty) return false;
    for (final r in _rows) {
      if (r.selectedCC == null) return false;
      if ((double.tryParse(r.percentCtrl.text) ?? 0) <= 0) return false;
    }
    return (_totalPercent - 100).abs() < 0.01;
  }

  void _addRow() {
    final remaining = (100 - _totalPercent).clamp(0.0, 100.0);
    final pctStr = remaining % 1 == 0
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(1);
    setState(() => _rows.add(_AllocationRow(initialPercent: pctStr)));
  }

  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  void _save() {
    if (!_isValid) return;
    final allocations = _rows.map((r) {
      return CostCenterAllocation(
        costCenterId: r.selectedCC!.costCenterId,
        costCenterName: r.selectedCC!.displayName,
        subCostCenterId: r.selectedSCC?.subCostCenterId,
        subCostCenterName: r.selectedSCC?.displayName,
        subSubCostCenterId: r.selectedSSCC?.subSubCostCenterId,
        subSubCostCenterName: r.selectedSSCC?.displayName,
        percentage: double.tryParse(r.percentCtrl.text) ?? 0,
      );
    }).toList();
    final savedData = _rows.map((r) {
      final m = <String, dynamic>{
        'costCenterId': r.selectedCC!.costCenterId,
        'costCenterName': r.selectedCC!.displayName,
        'percentage': double.tryParse(r.percentCtrl.text) ?? 0,
      };
      if (r.selectedSCC != null) {
        m['subCostCenterId'] = r.selectedSCC!.subCostCenterId;
        m['subCostCenterName'] = r.selectedSCC!.displayName;
      }
      if (r.selectedSSCC != null) {
        m['subSubCostCenterId'] = r.selectedSSCC!.subSubCostCenterId;
        m['subSubCostCenterName'] = r.selectedSSCC!.displayName;
      }
      return m;
    }).toList();
    context.read<StorageService>().saveLastAllocations(savedData);
    Navigator.of(context).pop(allocations);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Centros de costo'),
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _rows.length,
                    itemBuilder: (_, i) => _RowCard(
                      row: _rows[i],
                      index: i,
                      costCenters: _costCenters,
                      service: context.read<CostCenterService>(),
                      onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
                _BottomBar(
                  total: _totalPercent,
                  isValid: _isValid,
                  onAdd: _addRow,
                  onSave: _save,
                ),
              ],
            ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _AllocationRow {
  CostCenterModel? selectedCC;
  SubCostCenterModel? selectedSCC;
  SubSubCostCenterModel? selectedSSCC;
  final TextEditingController percentCtrl;
  List<SubCostCenterModel> subCenters = [];
  List<SubSubCostCenterModel> subSubCenters = [];

  _AllocationRow({String initialPercent = '100'})
      : percentCtrl = TextEditingController(text: initialPercent);

  void dispose() => percentCtrl.dispose();
}

// ── Row card ──────────────────────────────────────────────────────────────────

class _RowCard extends StatefulWidget {
  final _AllocationRow row;
  final int index;
  final List<CostCenterModel> costCenters;
  final CostCenterService service;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _RowCard({
    required this.row,
    required this.index,
    required this.costCenters,
    required this.service,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _loadingSCC = false;
  bool _loadingSSCC = false;

  Future<void> _onCCSelected(CostCenterModel? cc) async {
    widget.row.selectedCC = cc;
    widget.row.selectedSCC = null;
    widget.row.selectedSSCC = null;
    widget.row.subCenters = [];
    widget.row.subSubCenters = [];
    if (cc == null) {
      setState(() {});
      widget.onChanged();
      return;
    }
    setState(() => _loadingSCC = true);
    try {
      final subs = await widget.service
          .getSubCostCenters(costCenterId: cc.costCenterId);
      widget.row.subCenters = subs;
    } catch (_) {}
    setState(() => _loadingSCC = false);
    widget.onChanged();
  }

  Future<void> _onSCCSelected(SubCostCenterModel? scc) async {
    widget.row.selectedSCC = scc;
    widget.row.selectedSSCC = null;
    widget.row.subSubCenters = [];
    if (scc == null) {
      setState(() {});
      widget.onChanged();
      return;
    }
    setState(() => _loadingSSCC = true);
    try {
      final subsubs = await widget.service
          .getSubSubCostCenters(subCostCenterId: scc.subCostCenterId);
      widget.row.subSubCenters = subsubs;
    } catch (_) {}
    setState(() => _loadingSSCC = false);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final row = widget.row;
    final barColors = [
      AppTheme.primary, AppTheme.mint, AppTheme.coral,
      AppTheme.violet, AppTheme.sky,
    ];
    final accentColor = barColors[widget.index % barColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Centro ${widget.index + 1}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
                const Spacer(),
                if (widget.onRemove != null)
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppTheme.error, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: c.line),
            const SizedBox(height: 14),

            // Centro de costo
            const _FieldLabel('Centro de costo *'),
            const SizedBox(height: 6),
            _Dropdown<CostCenterModel>(
              value: row.selectedCC,
              items: widget.costCenters,
              itemLabel: (e) => e.displayName,
              onChanged: _onCCSelected,
            ),

            // Sub centro
            if (row.selectedCC != null) ...[
              const SizedBox(height: 12),
              const _FieldLabel('Sub centro de costo'),
              const SizedBox(height: 6),
              _loadingSCC
                  ? const _LoadingIndicator()
                  : _Dropdown<SubCostCenterModel>(
                      value: row.selectedSCC,
                      items: row.subCenters,
                      itemLabel: (e) => e.displayName,
                      onChanged: _onSCCSelected,
                    ),
            ],

            // Sub sub centro
            if (row.selectedSCC != null && row.subSubCenters.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _FieldLabel('Sub sub centro'),
              const SizedBox(height: 6),
              _loadingSSCC
                  ? const _LoadingIndicator()
                  : _Dropdown<SubSubCostCenterModel>(
                      value: row.selectedSSCC,
                      items: row.subSubCenters,
                      itemLabel: (e) => e.displayName,
                      onChanged: (v) {
                        setState(() => row.selectedSSCC = v);
                        widget.onChanged();
                      },
                    ),
            ],

            const SizedBox(height: 14),
            const _FieldLabel('Porcentaje *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: row.percentCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => widget.onChanged(),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: '%',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final pct in [25.0, 33.3, 50.0, 100.0])
                  _PctChip(
                    label: pct == 33.3 ? '33.3%' : '${pct.toInt()}%',
                    selected: row.percentCtrl.text ==
                        (pct == 33.3 ? '33.3' : pct.toInt().toString()),
                    onTap: () {
                      setState(() {
                        row.percentCtrl.text =
                            pct == 33.3 ? '33.3' : pct.toInt().toString();
                      });
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Text(text,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: c.ink2));
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _PctChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PctChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : c.surfaceTinted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : c.muted,
          ),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text('Seleccionar...',
              style: TextStyle(color: c.muted, fontSize: 14)),
        ),
        ...items.map((e) => DropdownMenuItem<T>(
              value: e,
              child: Text(itemLabel(e),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: c.ink)),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final double total;
  final bool isValid;
  final VoidCallback onAdd;
  final VoidCallback onSave;

  const _BottomBar({
    required this.total,
    required this.isValid,
    required this.onAdd,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final diff = 100 - total;
    final ok = diff.abs() < 0.01;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de progreso del total
          Row(
            children: [
              Text('Total asignado',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.muted)),
              const Spacer(),
              Text(
                '${total.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ok ? AppTheme.secondary : AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (total / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: c.surfaceTinted,
              color: ok
                  ? AppTheme.secondary
                  : total > 100
                      ? AppTheme.error
                      : AppTheme.primary,
            ),
          ),
          if (!ok) ...[
            const SizedBox(height: 6),
            const Text('', // placeholder replaced below
              style: TextStyle(fontSize: 0),
            ),
            Text(
              diff > 0
                  ? 'Falta asignar ${diff.toStringAsFixed(1)}%'
                  : 'Excede en ${(-diff).toStringAsFixed(1)}%',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: onAdd,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  maximumSize: const Size(50, 50),
                  padding: EdgeInsets.zero,
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: c.line, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('+',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: isValid ? onSave : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Listo',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
