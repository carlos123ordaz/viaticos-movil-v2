import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/cost_center_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/expense_service.dart';
import '../../providers/expense_provider.dart';
import 'cost_center_allocation_screen.dart';

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;
  const EditExpenseScreen({super.key, required this.expenseId});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  String _type = 'viatico';

  final _rucCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _totalCtrl = TextEditingController();
  final _igvCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0.00');
  final _detractionCtrl = TextEditingController(text: '0.00');
  String _currency = 'PEN';

  ExpenseCategoryModel? _selectedCategory;
  DateTime _date = DateTime.now();

  ReceiptTypeModel? _receiptType;
  final _receiptNumberCtrl = TextEditingController();
  String? _documentType;
  final _docReferenceCtrl = TextEditingController();

  final _descripCtrl = TextEditingController();
  List<CostCenterAllocation> _allocations = [];
  List<_ItemData> _items = [];
  String? _imageUrl;

  List<ExpenseCategoryModel> _categories = [];
  List<ReceiptTypeModel> _receiptTypes = [];

  bool _loadingData = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final service = context.read<ExpenseService>();
    try {
      final expense = await service.getExpense(widget.expenseId);
      final expenseType = expense.type ?? 'viatico';
      final results = await Future.wait([
        service.getExpenseCategories(expenseType),
        service.getReceiptTypes(),
      ]);
      final categories = results[0] as List<ExpenseCategoryModel>;
      final receiptTypes = results[1] as List<ReceiptTypeModel>;

      setState(() {
        _type = expenseType;
        _rucCtrl.text = expense.ruc ?? '';
        _businessNameCtrl.text = expense.businessName ?? '';
        _addressCtrl.text = expense.address ?? '';
        _totalCtrl.text = expense.amount.toStringAsFixed(2);
        _igvCtrl.text = expense.igv.toStringAsFixed(2);
        _discountCtrl.text = (expense.discount ?? 0).toStringAsFixed(2);
        _detractionCtrl.text = (expense.detraction ?? 0).toStringAsFixed(2);
        _currency = expense.currency;
        _date = expense.date;
        _descripCtrl.text = expense.descrip ?? '';
        _receiptNumberCtrl.text = expense.receiptNumber ?? '';
        _documentType = expense.documentType;
        _docReferenceCtrl.text = expense.documentReference ?? '';
        _allocations = expense.costCenterAllocations;
        _imageUrl = expense.imageUrl;
        _items = expense.items.map((i) => _ItemData.fromMap(i.toJson())).toList();
        _categories = categories;
        _receiptTypes = receiptTypes;
        _selectedCategory = categories.where((c) => c.name == expense.categoryName).firstOrNull;
        _receiptType = receiptTypes.where((r) => r.name == expense.receiptDetail).firstOrNull;
        _loadingData = false;
      });
    } catch (_) {
      setState(() => _loadingData = false);
    }
  }

  void _setType(String type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _selectedCategory = null;
      _categories = [];
    });
    context.read<ExpenseService>().getExpenseCategories(type).then((cats) {
      if (mounted) setState(() => _categories = cats);
    }).catchError((_) {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _addItem() => setState(() => _items.add(_ItemData()));
  void _removeItem(int i) => setState(() => _items.removeAt(i));

  void _updateTotalFromItems() {
    if (_items.isEmpty) return;
    final total = _items.fold(0.0, (s, item) => s + item.subtotal);
    _totalCtrl.text = total.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _openAllocationScreen() async {
    final result = await Navigator.of(context).push<List<CostCenterAllocation>>(
      MaterialPageRoute(builder: (_) => CostCenterAllocationScreen(initialAllocations: _allocations)),
    );
    if (result != null) setState(() => _allocations = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.'));
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto total válido')),
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'type': _type,
      'expenseDate': _date.toIso8601String(),
      'total': total,
      'currencyCode': _currency,
      'igv': double.tryParse(_igvCtrl.text.replaceAll(',', '.')) ?? 0,
      'discount': double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0,
      'detraction': double.tryParse(_detractionCtrl.text.replaceAll(',', '.')) ?? 0,
      'imageUrl': _imageUrl ?? '',
      if (_rucCtrl.text.trim().isNotEmpty) 'ruc': _rucCtrl.text.trim(),
      if (_businessNameCtrl.text.trim().isNotEmpty) 'businessName': _businessNameCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
      if (_selectedCategory != null) 'category': _selectedCategory!.name,
      if (_descripCtrl.text.trim().isNotEmpty) 'descrip': _descripCtrl.text.trim(),
      if (_receiptType != null) 'receiptDetail': _receiptType!.name,
      if (_receiptType != null) 'receiptTypeId': _receiptType!.receiptTypeId,
      if (_receiptNumberCtrl.text.trim().isNotEmpty) 'receiptNumber': _receiptNumberCtrl.text.trim(),
      if (_documentType != null) 'documentType': _documentType,
      if (_docReferenceCtrl.text.trim().isNotEmpty) 'documentReference': _docReferenceCtrl.text.trim(),
      if (_items.isNotEmpty)
        'items': _items.map((i) => {
              'descrip': i.descripCtrl.text.trim(),
              'unitOfMeasure': i.unitCtrl.text.trim(),
              'quantity': double.tryParse(i.quantityCtrl.text) ?? 1,
              'unitPrice': double.tryParse(i.priceCtrl.text) ?? 0,
              'subtotal': i.subtotal,
            }).toList(),
      if (_allocations.isNotEmpty) 'costCenterAllocations': _allocations.map((a) => a.toJson()).toList(),
    };
    final updated = await context.read<ExpenseProvider>().update(widget.expenseId, body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gasto actualizado')));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Error al actualizar el gasto'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  void dispose() {
    _rucCtrl.dispose();
    _businessNameCtrl.dispose();
    _addressCtrl.dispose();
    _totalCtrl.dispose();
    _igvCtrl.dispose();
    _discountCtrl.dispose();
    _detractionCtrl.dispose();
    _receiptNumberCtrl.dispose();
    _docReferenceCtrl.dispose();
    _descripCtrl.dispose();
    for (final item in _items) item.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar gasto'),
        actions: [
          TextButton(
            onPressed: _loadingData || _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, color: colors.primary)),
          ),
        ],
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SectionHeader('Tipo de gasto'),
                  const SizedBox(height: 10),
                  _TypeToggle(type: _type, onChanged: _setType),
                  const SizedBox(height: 24),

                  _SectionHeader('Proveedor'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _rucCtrl,
                    decoration: const InputDecoration(labelText: 'RUC', prefixIcon: Icon(Icons.numbers_rounded)),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _businessNameCtrl,
                    decoration: const InputDecoration(labelText: 'Razón Social', prefixIcon: Icon(Icons.business_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.location_on_outlined)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader('Montos'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _totalCtrl,
                          validator: Validators.amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Total *',
                            prefixText: _currency == 'USD' ? '\$ ' : _currency == 'EUR' ? '€ ' : 'S/ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: colors.outline), borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currency,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            borderRadius: BorderRadius.circular(12),
                            onChanged: (v) => setState(() => _currency = v!),
                            items: const [
                              DropdownMenuItem(value: 'PEN', child: Text('S/')),
                              DropdownMenuItem(value: 'USD', child: Text('\$')),
                              DropdownMenuItem(value: 'EUR', child: Text('€')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _igvCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'IGV', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _discountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Descuento', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: _detractionCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Detracción', isDense: true))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader('Categoría y Fecha'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ExpenseCategoryModel>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.label_outline)),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(border: Border.all(color: colors.outline), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: colors.onSurface.withOpacity(0.6), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down_rounded, color: colors.onSurface.withOpacity(0.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader('Comprobante'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ReceiptTypeModel>(
                    value: _receiptType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tipo de sustento', prefixIcon: Icon(Icons.article_outlined)),
                    items: [
                      const DropdownMenuItem<ReceiptTypeModel>(value: null, child: Text('Seleccionar...')),
                      ..._receiptTypes.map((r) => DropdownMenuItem(value: r, child: Text(r.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _receiptType = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _receiptNumberCtrl,
                    decoration: const InputDecoration(labelText: 'Número de comprobante', prefixIcon: Icon(Icons.tag_rounded)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _documentType,
                    decoration: const InputDecoration(labelText: 'Tipo de documento', prefixIcon: Icon(Icons.description_outlined)),
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text('Ninguno')),
                      DropdownMenuItem<String?>(value: 'OC', child: Text('OC - Orden de Compra')),
                      DropdownMenuItem<String?>(value: 'OS', child: Text('OS - Orden de Servicio')),
                      DropdownMenuItem<String?>(value: 'PR', child: Text('PR - Pedido de Reposición')),
                    ],
                    onChanged: (v) => setState(() => _documentType = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _docReferenceCtrl,
                    decoration: const InputDecoration(labelText: 'Referencia del documento', prefixIcon: Icon(Icons.link_rounded)),
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader('Descripción'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descripCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Descripción general del gasto...', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionHeader('Items'),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar'),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.center,
                      child: Text('Sin items — opcional', style: TextStyle(color: colors.outline)),
                    )
                  else
                    ...List.generate(
                      _items.length,
                      (i) => _ItemTile(
                        item: _items[i],
                        index: i,
                        currency: _currency,
                        onRemove: () => _removeItem(i),
                        onChanged: _updateTotalFromItems,
                      ),
                    ),
                  const SizedBox(height: 24),

                  _SectionHeader('Centros de costo'),
                  const SizedBox(height: 10),
                  if (_allocations.isNotEmpty) ...[
                    ..._allocations.map((a) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: colors.primaryContainer,
                            child: Text('${a.percentage.toInt()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.primary)),
                          ),
                          title: Text(a.costCenterName ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: a.subCostCenterName != null ? Text(a.subCostCenterName!, style: const TextStyle(fontSize: 12)) : null,
                        )),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: _openAllocationScreen,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(_allocations.isEmpty ? 'Asignar centros de costo' : 'Editar asignación'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700));
  }
}

class _TypeToggle extends StatelessWidget {
  final String type;
  final void Function(String) onChanged;
  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: colors.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _TypeTab('viatico', 'Viático', type, onChanged)),
          Expanded(child: _TypeTab('compra', 'Compra', type, onChanged)),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String value, label, current;
  final void Function(String) onChanged;
  const _TypeTab(this.value, this.label, this.current, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                color: selected ? Colors.white : colors.onSurface.withOpacity(0.6))),
      ),
    );
  }
}

class _ItemData {
  final TextEditingController descripCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController priceCtrl;
  final double? _ocrSubtotal;

  _ItemData()
      : descripCtrl = TextEditingController(),
        unitCtrl = TextEditingController(),
        quantityCtrl = TextEditingController(text: '1'),
        priceCtrl = TextEditingController(),
        _ocrSubtotal = null;

  _ItemData.fromMap(Map<dynamic, dynamic> m)
      : descripCtrl = TextEditingController(text: m['descrip']?.toString() ?? ''),
        unitCtrl = TextEditingController(text: m['unitOfMeasure']?.toString() ?? ''),
        quantityCtrl = TextEditingController(text: m['quantity']?.toString() ?? '1'),
        priceCtrl = TextEditingController(text: m['unitPrice']?.toString() ?? ''),
        _ocrSubtotal = m['subtotal'] != null ? (m['subtotal'] as num).toDouble() : null;

  double get subtotal {
    final calculated = (double.tryParse(quantityCtrl.text) ?? 0) * (double.tryParse(priceCtrl.text) ?? 0);
    if (calculated == 0 && _ocrSubtotal != null && _ocrSubtotal! > 0) return _ocrSubtotal!;
    return calculated;
  }

  void dispose() {
    descripCtrl.dispose();
    unitCtrl.dispose();
    quantityCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ItemTile extends StatelessWidget {
  final _ItemData item;
  final int index;
  final String currency;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemTile({
    required this.item,
    required this.index,
    required this.currency,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final symbol = currency == 'USD' ? '\$' : currency == 'EUR' ? '€' : 'S/';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Item ${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.outline)),
              const Spacer(),
              GestureDetector(onTap: onRemove, child: Icon(Icons.close_rounded, color: colors.error, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: item.descripCtrl, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Descripción', isDense: true)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.quantityCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Cantidad', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: item.priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Precio unitario', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.unitCtrl,
            decoration: const InputDecoration(labelText: 'Unidad de medida', isDense: true),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Subtotal: $symbol ${item.subtotal.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.primary)),
          ),
        ],
      ),
    );
  }
}
