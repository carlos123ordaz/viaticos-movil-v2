import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/cost_center_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/expense_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import 'cost_center_allocation_screen.dart';
import 'task_selection_screen.dart';

const _kStepTitles = [
  'Tipo y Tarea',
  'Proveedor',
  'Montos e Items',
  'Categoría y Comprobante',
  'Descripción y Adjuntos',
];

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? prefillData;
  const AddExpenseScreen({super.key, this.prefillData});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageCtrl = PageController();
  int _currentStep = 0;

  // Tipo
  String _type = 'viatico';

  // Proveedor
  final _rucCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Items
  final List<_ItemData> _items = [];

  // Totales
  final _totalCtrl = TextEditingController();
  final _igvCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0.00');
  final _detractionCtrl = TextEditingController(text: '0.00');

  // Detalles
  ExpenseCategoryModel? _selectedCategory;
  String _currency = 'PEN';
  DateTime _date = DateTime.now();

  // Comprobante
  ReceiptTypeModel? _receiptType;
  final _receiptNumberCtrl = TextEditingController();
  String? _documentType;
  final _docReferenceCtrl = TextEditingController();

  // Descripción y adjuntos
  final _descripCtrl = TextEditingController();
  List<CostCenterAllocation> _allocations = [];
  String? _imagePath;
  String? _imageUrl;
  String? _receiptDetailId;
  bool _fromScan = false;
  bool _hasReceipt = true;

  // Datos del servidor
  List<ExpenseCategoryModel> _categories = [];
  List<ReceiptTypeModel> _receiptTypes = [];
  bool _loadingData = true;
  bool _saving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.prefillData != null) _applyPrefill(widget.prefillData!);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _applyPrefill(Map<String, dynamic> data) {
    _rucCtrl.text = data['ruc']?.toString() ?? '';
    _businessNameCtrl.text = data['businessName']?.toString() ?? '';
    _addressCtrl.text = data['address']?.toString() ?? '';
    _descripCtrl.text = (data['descrip'] ?? data['description'])?.toString() ?? '';
    if (data['total'] != null) _totalCtrl.text = data['total'].toString();
    if (data['igv'] != null) _igvCtrl.text = data['igv'].toString();
    if (data['discount'] != null) _discountCtrl.text = data['discount'].toString();
    if (data['detraction'] != null) _detractionCtrl.text = data['detraction'].toString();
    if (data['type'] != null) _type = data['type'] as String;
    if (data['currencyCode'] != null) _currency = data['currencyCode'] as String;
    if (data['receiptNumber'] != null) _receiptNumberCtrl.text = data['receiptNumber'].toString();
    if (data['imageUrl'] != null) _imageUrl = data['imageUrl'] as String;
    if (data['hasReceipt'] is bool) _hasReceipt = data['hasReceipt'] as bool;
    if (data['receiptDetail'] != null) _receiptDetailId = data['receiptDetail'].toString();
    if (data['scannedFilePath'] != null) {
      _imagePath = data['scannedFilePath'] as String;
      _fromScan = true;
    }
    if (data['items'] is List) {
      final list = data['items'] as List;
      _items.addAll(list.map((e) => _ItemData.fromMap(e as Map)));
    }
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    final service = context.read<ExpenseService>();
    try {
      final results = await Future.wait([
        service.getExpenseCategories(_type),
        service.getReceiptTypes(),
      ]);
      setState(() {
        _categories = results[0] as List<ExpenseCategoryModel>;
        _receiptTypes = results[1] as List<ReceiptTypeModel>;
      });
    } catch (_) {
    } finally {
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
    _loadData();
  }

  void _recalcIgv() {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    if (total > 0) _igvCtrl.text = (total - total / 1.18).toStringAsFixed(2);
  }

  void _addItem() => setState(() => _items.add(_ItemData()));
  void _removeItem(int i) => setState(() => _items.removeAt(i));

  void _updateTotalFromItems() {
    if (_items.isEmpty) return;
    final total = _items.fold(0.0, (s, item) => s + item.subtotal);
    _totalCtrl.text = total.toStringAsFixed(2);
    _recalcIgv();
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    final result = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (result != null) setState(() => _imagePath = result.path);
  }

  Future<void> _openAllocationScreen() async {
    final result = await Navigator.of(context).push<List<CostCenterAllocation>>(
      MaterialPageRoute(builder: (_) => CostCenterAllocationScreen(initialAllocations: _allocations)),
    );
    if (result != null) setState(() => _allocations = result);
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (context.read<AuthProvider>().taskId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes seleccionar una tarea antes de continuar')),
          );
          return false;
        }
        return true;
      case 2:
        final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.'));
        if (total == null || total <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingresa un monto total válido')),
          );
          return false;
        }
        return true;
      case 3:
        if (_selectedCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona una categoría')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _goNext() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goPrev() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _submit() async {
    if (!_validateStep(2) || !_validateStep(3)) return;
    final total = double.tryParse(_totalCtrl.text.replaceAll(',', '.'));
    if (total == null || total <= 0) return;

    if (_allocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe asignar al menos un centro de costo')),
      );
      return;
    }
    final totalPct = _allocations.fold(0.0, (s, a) => s + a.percentage);
    if ((totalPct - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Los porcentajes deben sumar 100% (actual: ${totalPct.toStringAsFixed(0)}%)')),
      );
      return;
    }

    setState(() => _saving = true);
    final taskId = context.read<AuthProvider>().taskId;
    final body = <String, dynamic>{
      'type': _type,
      'expenseDate': _date.toIso8601String(),
      'total': total,
      'currencyCode': _currency,
      'igv': double.tryParse(_igvCtrl.text.replaceAll(',', '.')) ?? 0,
      'discount': double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0,
      'detraction': double.tryParse(_detractionCtrl.text.replaceAll(',', '.')) ?? 0,
      'hasReceipt': _hasReceipt,
      'creationMethod': _fromScan ? 'scan' : 'manual',
      'imageUrl': _imageUrl ?? '',
      'receiptDetail': _receiptType?.name ?? _receiptDetailId ?? '',
      'receiptNumber': _receiptNumberCtrl.text.trim(),
      'ruc': _rucCtrl.text.trim(),
      'businessName': _businessNameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'descrip': _descripCtrl.text.trim(),
      'documentReference': _docReferenceCtrl.text.trim(),
      if (_selectedCategory != null) 'category': _selectedCategory!.name,
      if (_documentType != null) 'documentType': _documentType,
      if (taskId != null) 'taskId': taskId,
      if (_items.isNotEmpty)
        'items': _items.map((i) => {
              'descrip': i.descripCtrl.text.trim(),
              'unitOfMeasure': i.unitCtrl.text.trim(),
              'quantity': double.tryParse(i.quantityCtrl.text) ?? 1,
              'unitPrice': double.tryParse(i.priceCtrl.text) ?? 0,
              'subtotal': i.subtotal,
            }).toList(),
      'costCenterAllocations': _allocations.map((a) => a.toJson()).toList(),
    };

    final provider = context.read<ExpenseProvider>();
    final expense = await provider.create(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (expense != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gasto registrado correctamente')),
      );
      context.pop();
    } else {
      final errorMsg = provider.createError ?? 'Error al guardar el gasto';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
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
        title: Text(_kStepTitles[_currentStep]),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Indicador de pasos
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: List.generate(5, (i) {
                  final done = i < _currentStep;
                  final active = i == _currentStep;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 4,
                            decoration: BoxDecoration(
                              color: done || active ? colors.primary : colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i < 4) const SizedBox(width: 4),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paso ${_currentStep + 1} de 5',
                      style: TextStyle(fontSize: 12, color: colors.outline, fontWeight: FontWeight.w500)),
                  Text(_kStepTitles[_currentStep],
                      style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Contenido de pasos
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepView(child: _buildStep0(colors)),
                  _StepView(child: _buildStep1(colors)),
                  _StepView(child: _buildStep2(colors)),
                  _StepView(child: _buildStep3(colors)),
                  _StepView(child: _buildStep4(colors)),
                ],
              ),
            ),
            // Navegación inferior
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: _goPrev,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Anterior'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _currentStep < 4
                        ? FilledButton.icon(
                            onPressed: _goNext,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          )
                        : FilledButton.icon(
                            onPressed: _saving ? null : _submit,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(_saving ? 'Guardando...' : 'Registrar',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 0: Tipo y Tarea ────────────────────────────────────────────────────
  Widget _buildStep0(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de gasto', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface)),
        const SizedBox(height: 12),
        _TypeToggle(type: _type, onChanged: _setType),
        const SizedBox(height: 24),
        Text('Tarea Bitrix', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurface)),
        const SizedBox(height: 12),
        _TaskBanner(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Seleccionar una tarea Bitrix es obligatorio para registrar un gasto.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Paso 1: Proveedor ───────────────────────────────────────────────────────
  Widget _buildStep1(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Datos del proveedor',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Todos los campos son opcionales', style: TextStyle(fontSize: 12, color: colors.outline)),
        const SizedBox(height: 16),
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
      ],
    );
  }

  // ── Paso 2: Montos e Items ──────────────────────────────────────────────────
  Widget _buildStep2(ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _totalCtrl,
                validator: Validators.amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                onEditingComplete: _recalcIgv,
                decoration: InputDecoration(
                  labelText: 'Total *',
                  prefixText: _currency == 'USD' ? '\$ ' : _currency == 'EUR' ? '€ ' : 'S/ ',
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: _CurrencyPicker(value: _currency, onChanged: (v) => setState(() => _currency = v!)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _igvCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'IGV', isDense: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Descuento', isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _detractionCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Detracción', isDense: true),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Items del comprobante',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
            (i) => _ItemTile(item: _items[i], index: i, onRemove: () => _removeItem(i), onChanged: _updateTotalFromItems),
          ),
      ],
    );
  }

  // ── Paso 3: Categoría y Comprobante ────────────────────────────────────────
  Widget _buildStep3(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categoría', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _loadingData
            ? const Center(child: CircularProgressIndicator())
            : DropdownButtonFormField<ExpenseCategoryModel>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría *', prefixIcon: Icon(Icons.label_outline)),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) => v == null ? 'Selecciona una categoría' : null,
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
        const SizedBox(height: 20),
        Text('Comprobante', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        DropdownButtonFormField<ReceiptTypeModel>(
          value: _receiptType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de sustento', prefixIcon: Icon(Icons.article_outlined)),
          items: _receiptTypes.map((r) => DropdownMenuItem(value: r, child: Text(r.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _receiptType = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _receiptNumberCtrl,
          decoration: const InputDecoration(labelText: 'Número de comprobante', prefixIcon: Icon(Icons.tag_rounded)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _documentType,
          decoration: const InputDecoration(labelText: 'Tipo de documento', prefixIcon: Icon(Icons.description_outlined)),
          items: const [
            DropdownMenuItem(value: 'OC', child: Text('OC - Orden de Compra')),
            DropdownMenuItem(value: 'OS', child: Text('OS - Orden de Servicio')),
            DropdownMenuItem(value: 'PR', child: Text('PR - Pedido de Reposición')),
          ],
          onChanged: (v) => setState(() => _documentType = v),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _docReferenceCtrl,
          decoration: const InputDecoration(labelText: 'Referencia del documento', prefixIcon: Icon(Icons.link_rounded)),
        ),
      ],
    );
  }

  // ── Paso 4: Descripción y Adjuntos ──────────────────────────────────────────
  Widget _buildStep4(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Descripción', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descripCtrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Descripción general del gasto...', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Text('Centros de costo', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_allocations.isNotEmpty) ...[
          ..._allocations.map((a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16, backgroundColor: colors.primaryContainer,
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
        if (_fromScan) ...[
          const SizedBox(height: 20),
          Text('Imagen del comprobante', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.secondary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  _imagePath!.toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_rounded
                      : Icons.check_circle_rounded,
                  color: colors.secondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprobante adjuntado',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.secondary),
                      ),
                      Text(
                        _imagePath!.split('/').last,
                        style: TextStyle(fontSize: 12, color: colors.secondary.withOpacity(0.7)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Adjuntar comprobante', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar foto'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de galería'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets de paso ──────────────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  final Widget child;
  const _StepView({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [child],
    );
  }
}

// ─── Widgets auxiliares (mismo que antes) ─────────────────────────────────────

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
          Expanded(child: _Tab('viatico', 'Viático', type, onChanged)),
          Expanded(child: _Tab('compra', 'Compra', type, onChanged)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String value, label, current;
  final void Function(String) onChanged;
  const _Tab(this.value, this.label, this.current, this.onChanged);

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

class _TaskBanner extends StatelessWidget {
  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskSelectionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colors = Theme.of(context).colorScheme;
    if (auth.taskId == null) {
      return OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: const Text('Seleccionar tarea Bitrix'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46), side: BorderSide(color: colors.outline.withOpacity(0.5))),
      );
    }
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: colors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auth.taskName ?? 'Tarea seleccionada',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primary), overflow: TextOverflow.ellipsis),
                  Text('ID: ${auth.taskId}', style: TextStyle(fontSize: 11, color: colors.primary.withOpacity(0.7))),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 16, color: colors.primary.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _CurrencyPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: colors.outline), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, padding: const EdgeInsets.symmetric(horizontal: 12),
          borderRadius: BorderRadius.circular(12), onChanged: onChanged,
          items: const [
            DropdownMenuItem(value: 'PEN', child: Text('S/')),
            DropdownMenuItem(value: 'USD', child: Text('\$')),
            DropdownMenuItem(value: 'EUR', child: Text('€')),
          ],
        ),
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
    // Si el precio no fue ingresado pero el OCR tenía subtotal, usar ese valor
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
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemTile({required this.item, required this.index, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
            child: Text('Subtotal: S/ ${item.subtotal.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.primary)),
          ),
        ],
      ),
    );
  }
}
