import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        rows = widget.initialAllocations
            .map((a) => _AllocationRow.fromAllocation(a))
            .toList();
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
            final pctStr = pct % 1 == 0 ? pct.toInt().toString() : pct.toStringAsFixed(1);
            final row = _AllocationRow(initialPercent: pctStr);
            if (cc != null) {
              row.selectedCC = cc;
              final sccId = (s['subCostCenterId'] as num?)?.toInt();
              if (sccId != null) {
                try {
                  final subs = await service.getSubCostCenters(costCenterId: cc.costCenterId);
                  row.subCenters = subs;
                  row.selectedSCC = subs.where((sub) => sub.subCostCenterId == sccId).firstOrNull;
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
            final cc = centers.where((c) => c.costCenterId == userCCId).firstOrNull;
            if (cc != null) {
              row.selectedCC = cc;
              if (userSCCId != null) {
                try {
                  final subs = await service.getSubCostCenters(costCenterId: cc.costCenterId);
                  row.subCenters = subs;
                  row.selectedSCC = subs.where((s) => s.subCostCenterId == userSCCId).firstOrNull;
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
    final pctStr = remaining % 1 == 0 ? remaining.toInt().toString() : remaining.toStringAsFixed(1);
    setState(() => _rows.add(_AllocationRow(initialPercent: pctStr)));
  }

  void _removeRow(int i) {
    setState(() => _rows.removeAt(i));
  }

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
        'percentage': double.tryParse(r.percentCtrl.text) ?? 0,
      };
      if (r.selectedSCC != null) m['subCostCenterId'] = r.selectedSCC!.subCostCenterId;
      if (r.selectedSSCC != null) m['subSubCostCenterId'] = r.selectedSSCC!.subSubCostCenterId;
      return m;
    }).toList();
    context.read<StorageService>().saveLastAllocations(savedData);
    Navigator.of(context).pop(allocations);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centros de Costo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
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

class _AllocationRow {
  CostCenterModel? selectedCC;
  SubCostCenterModel? selectedSCC;
  SubSubCostCenterModel? selectedSSCC;
  final TextEditingController percentCtrl;
  List<SubCostCenterModel> subCenters = [];
  List<SubSubCostCenterModel> subSubCenters = [];

  _AllocationRow({String initialPercent = '100'})
      : percentCtrl = TextEditingController(text: initialPercent);

  _AllocationRow.fromAllocation(CostCenterAllocation a)
      : percentCtrl =
            TextEditingController(text: a.percentage.toStringAsFixed(0));

  void dispose() => percentCtrl.dispose();
}

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
      final subs = await widget.service.getSubCostCenters(costCenterId: cc.costCenterId);
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
    final colors = Theme.of(context).colorScheme;
    final row = widget.row;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.primary),
                  ),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: Icon(Icons.close_rounded, color: colors.error, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Dropdown<CostCenterModel>(
              label: 'Centro de costo *',
              value: row.selectedCC,
              items: widget.costCenters,
              itemLabel: (e) => e.displayName,
              onChanged: _onCCSelected,
            ),
            if (row.selectedCC != null) ...[
              const SizedBox(height: 10),
              _loadingSCC
                  ? const Center(
                      child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : _Dropdown<SubCostCenterModel>(
                      label: 'Sub centro de costo',
                      value: row.selectedSCC,
                      items: row.subCenters,
                      itemLabel: (e) => e.displayName,
                      onChanged: _onSCCSelected,
                    ),
            ],
            if (row.selectedSCC != null && row.subSubCenters.isNotEmpty) ...[
              const SizedBox(height: 10),
              _loadingSSCC
                  ? const Center(
                      child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : _Dropdown<SubSubCostCenterModel>(
                      label: 'Sub sub centro',
                      value: row.selectedSSCC,
                      items: row.subSubCenters,
                      itemLabel: (e) => e.displayName,
                      onChanged: (v) {
                        setState(() => row.selectedSSCC = v);
                        widget.onChanged();
                      },
                    ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: row.percentCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => widget.onChanged(),
              decoration: const InputDecoration(
                labelText: 'Porcentaje *',
                suffixText: '%',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final pct in [25.0, 33.3, 50.0, 100.0])
                  ChoiceChip(
                    label: Text(
                      pct == 33.3 ? '33.3%' : '${pct.toInt()}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: row.percentCtrl.text ==
                        (pct == 33.3 ? '33.3' : pct.toInt().toString()),
                    onSelected: (_) {
                      setState(() {
                        row.percentCtrl.text =
                            pct == 33.3 ? '33.3' : pct.toInt().toString();
                      });
                      widget.onChanged();
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text('Seleccionar...', style: TextStyle(color: colors.outline)),
        ),
        ...items.map((e) => DropdownMenuItem<T>(
              value: e,
              child: Text(itemLabel(e),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            )),
      ],
      onChanged: onChanged,
    );
  }
}

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
    final colors = Theme.of(context).colorScheme;
    final diff = 100 - total;
    final ok = diff.abs() < 0.01;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Total asignado:',
                  style: TextStyle(color: colors.outline, fontSize: 13)),
              const Spacer(),
              Text(
                '${total.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: ok ? colors.primary : colors.error,
                ),
              ),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: 4),
            Text(
              diff > 0
                  ? 'Falta asignar ${diff.toStringAsFixed(1)}%'
                  : 'Excede en ${(-diff).toStringAsFixed(1)}%',
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isValid ? onSave : null,
              child: const Text(
                'Listo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar centro de costo'),
            ),
          ),
        ],
      ),
    );
  }
}
