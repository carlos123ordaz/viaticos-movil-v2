import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/cost_center_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/cost_center_service.dart';
import '../../../data/services/expense_service.dart';
import '../../../data/services/storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import 'cost_center_allocation_screen.dart';
import 'task_selection_screen.dart';

const _kStepTitles = [
  '¿Qué tipo de gasto es?',
  'Datos del proveedor',
  'Montos del gasto',
  'Tipo de comprobante',
  'Detalle y respaldo',
];

const _kStepSubtitles = [
  'Elige el tipo y la tarea Bitrix asociada.',
  'Busca por RUC y completamos los datos.',
  'Ingresa el total. El IGV se calcula automáticamente.',
  'Define qué documento sustenta el gasto.',
  'Agrega descripción, comprobante y centros de costo.',
];

// ─────────────────────────────────────────────────────────────────────────────
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

  String _type = 'viatico';

  final _rucCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final List<_ItemData> _items = [];

  final _totalCtrl = TextEditingController();
  final _igvCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0.00');
  final _detractionCtrl = TextEditingController(text: '0.00');

  ExpenseCategoryModel? _selectedCategory;
  String _currency = 'PEN';
  DateTime _date = DateTime.now();

  ReceiptTypeModel? _receiptType;
  final _receiptNumberCtrl = TextEditingController();
  String? _documentType;
  final _docReferenceCtrl = TextEditingController();

  final _descripCtrl = TextEditingController();
  List<CostCenterAllocation> _allocations = [];
  String? _imagePath;
  String? _imageUrl;
  String? _receiptDetailId;
  int? _prefillReceiptTypeId;
  String? _prefillCategoryName;
  bool _fromScan = false;
  bool _hasReceipt = true;

  List<ExpenseCategoryModel> _categories = [];
  List<ReceiptTypeModel> _receiptTypes = [];
  bool _loadingData = true;
  bool _saving = false;

  final _picker = ImagePicker();

  String get _currencySymbol =>
      _currency == 'USD' ? '\$' : _currency == 'EUR' ? '€' : 'S/';

  double get _subtotalValue {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final igv = double.tryParse(_igvCtrl.text) ?? 0;
    return (total - igv).clamp(0, double.infinity);
  }

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
    if (data['expenseDate'] != null) {
      final parsed = DateTime.tryParse(data['expenseDate'].toString());
      if (parsed != null) _date = parsed;
    }
    if (data['imageUrl'] != null) _imageUrl = data['imageUrl'] as String;
    if (data['hasReceipt'] is bool) _hasReceipt = data['hasReceipt'] as bool;
    if (data['receiptDetail'] != null) _receiptDetailId = data['receiptDetail'].toString();
    if (data['receiptTypeId'] != null) _prefillReceiptTypeId = (data['receiptTypeId'] as num).toInt();
    if (data['category'] != null) _prefillCategoryName = data['category'].toString();
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
    final expenseService = context.read<ExpenseService>();
    final ccService = context.read<CostCenterService>();
    try {
      final results = await Future.wait([
        expenseService.getExpenseCategories(_type),
        expenseService.getReceiptTypes(),
        ccService.getCostCenters(),
      ]);
      final costCenters = results[2] as List<CostCenterModel>;
      setState(() {
        _categories = results[0] as List<ExpenseCategoryModel>;
        _receiptTypes = results[1] as List<ReceiptTypeModel>;
        if (_prefillCategoryName != null && _selectedCategory == null) {
          _selectedCategory = _categories
              .where((c) => c.name.toLowerCase() == _prefillCategoryName!.toLowerCase())
              .firstOrNull;
        }
        if (_prefillReceiptTypeId != null) {
          _receiptType = _receiptTypes
              .where((r) => r.receiptTypeId == _prefillReceiptTypeId)
              .firstOrNull;
        }
        _receiptType ??= _receiptTypes.where((r) => r.receiptTypeId == 2).firstOrNull;
      });
      // Pre-load saved allocations resolving names from the loaded cost center list
      if (_allocations.isEmpty) {
        final storage = context.read<StorageService>();
        final saved = storage.lastAllocations;
        if (saved != null && saved.isNotEmpty) {
          setState(() {
            _allocations = saved.map((s) {
              final ccId = (s['costCenterId'] as num?)?.toInt();
              final ccName = s['costCenterName'] as String? ??
                  costCenters
                      .where((c) => c.costCenterId == ccId)
                      .firstOrNull
                      ?.displayName;
              return CostCenterAllocation(
                costCenterId: ccId,
                costCenterName: ccName,
                subCostCenterId: (s['subCostCenterId'] as num?)?.toInt(),
                subCostCenterName: s['subCostCenterName'] as String?,
                subSubCostCenterId: (s['subSubCostCenterId'] as num?)?.toInt(),
                subSubCostCenterName: s['subSubCostCenterName'] as String?,
                percentage: (s['percentage'] as num).toDouble(),
              );
            }).toList();
          });
        }
      }
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
    if (total > 0) {
      _igvCtrl.text = (total - total / 1.18).toStringAsFixed(2);
      setState(() {});
    }
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
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    final result = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (result != null) setState(() => _imagePath = result.path);
  }

  Future<void> _openAllocationScreen() async {
    final result = await Navigator.of(context).push<List<CostCenterAllocation>>(
      MaterialPageRoute(
          builder: (_) => CostCenterAllocationScreen(initialAllocations: _allocations)),
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
      case 4:
        if (_descripCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La descripción es obligatoria')),
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
    if (!_validateStep(2) || !_validateStep(3) || !_validateStep(4)) return;
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
        SnackBar(
            content: Text(
                'Los porcentajes deben sumar 100% (actual: ${totalPct.toStringAsFixed(0)}%)')),
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
      if (_receiptType != null) 'receiptTypeId': _receiptType!.receiptTypeId,
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
        'items': _items
            .map((i) => {
                  'descrip': i.descripCtrl.text.trim(),
                  'unitOfMeasure': i.unitCtrl.text.trim(),
                  'quantity': double.tryParse(i.quantityCtrl.text) ?? 1,
                  'unitPrice': double.tryParse(i.priceCtrl.text) ?? 0,
                  'subtotal': i.subtotal,
                })
            .toList(),
      'costCenterAllocations': _allocations.map((a) => a.toJson()).toList(),
    };

    final provider = context.read<ExpenseProvider>();
    final expense = await provider.create(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (expense != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gasto registrado correctamente')));
      context.pop();
    } else {
      final errorMsg = provider.createError ?? 'Error al guardar el gasto';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 6)),
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

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _currentStep > 0 ? _goPrev : () => context.pop(),
                      icon: Icon(Icons.arrow_back_rounded, color: c.ink),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text('Cancelar',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.muted)),
                    ),
                  ],
                ),
              ),
              // Step header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PASO ${_currentStep + 1} DE 5',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Align(
                        key: ValueKey(_currentStep),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _kStepTitles[_currentStep],
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                              letterSpacing: -0.6,
                              height: 1.1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _kStepSubtitles[_currentStep],
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                    const SizedBox(height: 12),
                    // Segmented progress
                    Row(
                      children: List.generate(5, (i) {
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: i <= _currentStep ? AppTheme.primary : c.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              // Pages
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepView(child: _buildStep0()),
                    _StepView(child: _buildStep1()),
                    _StepView(child: _buildStep2()),
                    _StepView(child: _buildStep3()),
                    _StepView(child: _buildStep4()),
                  ],
                ),
              ),
              // Bottom nav
              Container(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                    color: c.surface, boxShadow: AppTheme.cardShadow),
                child: Row(
                  children: [
                    if (_currentStep > 0) ...[
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _goPrev,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: BorderSide(color: c.line, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Icon(Icons.arrow_back_rounded,
                              size: 20, color: c.ink),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _currentStep < 4
                          ? FilledButton(
                              onPressed: _goNext,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Siguiente',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                            )
                          : FilledButton(
                              onPressed: _saving ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.secondary,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_rounded, size: 18),
                                        SizedBox(width: 6),
                                        Text('Crear gasto',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paso 0: Tipo y Tarea ────────────────────────────────────────────────────

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Tipo de gasto'),
        const SizedBox(height: 10),
        _TypeToggle(type: _type, onChanged: _setType),
        const SizedBox(height: 24),
        const _FieldLabel('Tarea Bitrix'),
        const SizedBox(height: 10),
        _TaskBanner(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warnTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.warn.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warn),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Seleccionar una tarea Bitrix es obligatorio para registrar un gasto.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A4A10),
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Paso 1: Proveedor ───────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('RUC'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _rucCtrl,
          decoration: const InputDecoration(
              hintText: 'Ej: 20510016153',
              prefixIcon: Icon(Icons.numbers_rounded)),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Razón Social'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _businessNameCtrl,
          decoration: const InputDecoration(
              hintText: 'Nombre de la empresa',
              prefixIcon: Icon(Icons.business_outlined)),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Dirección'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
              hintText: 'Dirección fiscal',
              prefixIcon: Icon(Icons.location_on_outlined)),
          maxLines: 2,
        ),
      ],
    );
  }

  // ── Paso 2: Montos ──────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Currency pill selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: c.surfaceTinted,
              borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              for (final cur in [
                ('PEN', 'Soles · S/'),
                ('USD', 'Dólares · \$'),
                ('EUR', 'Euros · €')
              ])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currency = cur.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _currency == cur.$1 ? c.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: _currency == cur.$1
                            ? [const BoxShadow(
                                color: Color(0x180E1330),
                                blurRadius: 6,
                                offset: Offset(0, 2))]
                            : null,
                      ),
                      child: Text(cur.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _currency == cur.$1 ? c.ink : c.muted)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Dark total card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.ink,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x3A0E1330), blurRadius: 24, offset: Offset(0, 8))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_currencySymbol,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white60)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      controller: _totalCtrl,
                      validator: Validators.amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1),
                      onChanged: (_) => setState(() {}),
                      onEditingComplete: _recalcIgv,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        filled: false,
                        hintText: '0.00',
                        hintStyle: TextStyle(
                            color: Colors.white24,
                            fontSize: 44,
                            fontWeight: FontWeight.w800),
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amt in [50, 100, 500])
                    GestureDetector(
                      onTap: () {
                        final current = double.tryParse(_totalCtrl.text) ?? 0;
                        _totalCtrl.text = (current + amt).toStringAsFixed(2);
                        _recalcIgv();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('+$amt',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  GestureDetector(
                    onTap: _recalcIgv,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppTheme.yellow,
                          borderRadius: BorderRadius.circular(999)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calculate_rounded, size: 12, color: AppTheme.ink),
                          SizedBox(width: 4),
                          Text('Calc IGV',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 2×2 breakdown grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            _MoneyTile(
                label: 'IGV (18%)', controller: _igvCtrl, accent: AppTheme.primary),
            _MoneyTile(
                label: 'Subtotal',
                displayValue: _subtotalValue.toStringAsFixed(2)),
            _MoneyTile(
                label: 'Descuento', controller: _discountCtrl, optional: true),
            _MoneyTile(
                label: 'Detracción',
                controller: _detractionCtrl,
                optional: true),
          ],
        ),
        const SizedBox(height: 20),
        // Items
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _FieldLabel('Items del comprobante'),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Agregar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  foregroundColor: AppTheme.primary),
            ),
          ],
        ),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            child: Text('Sin items — opcional',
                style: TextStyle(fontSize: 13, color: c.muted)),
          )
        else
          ...List.generate(
            _items.length,
            (i) => _ItemTile(
                item: _items[i],
                index: i,
                onRemove: () => _removeItem(i),
                onChanged: _updateTotalFromItems),
          ),
      ],
    );
  }

  // ── Paso 3: Comprobante y Categoría ────────────────────────────────────────

  Widget _buildStep3() {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Tipo de sustento'),
        const SizedBox(height: 8),
        _loadingData
            ? const Center(child: CircularProgressIndicator())
            : DropdownButtonFormField<ReceiptTypeModel>(
                value: _receiptType,
                isExpanded: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.article_outlined), isDense: true),
                items: _receiptTypes
                    .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _receiptType = v),
              ),
        const SizedBox(height: 18),
        const _FieldLabel('Número de comprobante'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _receiptNumberCtrl,
          decoration: const InputDecoration(
              hintText: 'Ej: F001-00284192',
              prefixIcon: Icon(Icons.tag_rounded),
              isDense: true),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Categoría *'),
        const SizedBox(height: 8),
        _loadingData
            ? const Center(child: CircularProgressIndicator())
            : DropdownButtonFormField<ExpenseCategoryModel>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.label_outline), isDense: true),
                items: _categories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) => v == null ? 'Selecciona una categoría' : null,
              ),
        const SizedBox(height: 18),
        const _FieldLabel('Fecha de emisión'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.line, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: c.muted, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down_rounded, color: c.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Tipo de documento'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _documentType,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.description_outlined), isDense: true),
          items: const [
            DropdownMenuItem(value: 'OC', child: Text('OC - Orden de Compra')),
            DropdownMenuItem(value: 'OS', child: Text('OS - Orden de Servicio')),
            DropdownMenuItem(value: 'PR', child: Text('PR - Pedido de Reposición')),
          ],
          onChanged: (v) => setState(() => _documentType = v),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('Referencia del documento'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _docReferenceCtrl,
          decoration: const InputDecoration(
              hintText: 'Opcional',
              prefixIcon: Icon(Icons.link_rounded),
              isDense: true),
        ),
      ],
    );
  }

  // ── Paso 4: Descripción y adjuntos ──────────────────────────────────────────

  Widget _buildStep4() {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Descripción'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descripCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Descripción general del gasto...',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
        ),
        const SizedBox(height: 20),
        const _FieldLabel('Comprobante adjunto'),
        const SizedBox(height: 10),
        if (_imagePath != null || _imageUrl != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.secondary.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  (_imagePath ?? '').toLowerCase().endsWith('.pdf')
                      ? Icons.picture_as_pdf_rounded
                      : Icons.check_circle_rounded,
                  color: AppTheme.secondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Comprobante adjuntado',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondary)),
                      if (_imagePath != null)
                        Text(
                          _imagePath!.split('/').last,
                          style: TextStyle(fontSize: 12, color: c.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _imagePath = null;
                    if (!_fromScan) _imageUrl = null;
                  }),
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _AttachButton(
                icon: Icons.camera_alt_rounded,
                label: 'Cámara',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AttachButton(
                icon: Icons.photo_library_rounded,
                label: 'Galería',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const _FieldLabel('Centros de costo'),
            const Spacer(),
            if (_allocations.isNotEmpty)
              TextButton.icon(
                onPressed: _openAllocationScreen,
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text('Editar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_allocations.isEmpty)
          GestureDetector(
            onTap: _openAllocationScreen,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_tree_rounded,
                        color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Asignar centros de costo',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.ink)),
                        Text('Requerido para registrar el gasto',
                            style: TextStyle(fontSize: 11, color: c.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: c.muted2),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: _openAllocationScreen,
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: _allocations.asMap().entries.map((entry) {
                const barColors = [
                  AppTheme.primary, AppTheme.mint, AppTheme.coral,
                  AppTheme.violet, AppTheme.sky,
                ];
                final color = barColors[entry.key % barColors.length];
                final alloc = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: entry.key < _allocations.length - 1 ? 14 : 0),
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
                          Text('${alloc.percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ],
                      ),
                      if (alloc.subCostCenterName != null) ...[
                        const SizedBox(height: 2),
                        Text(alloc.subCostCenterName!,
                            style: TextStyle(
                                fontSize: 11, color: c.muted)),
                      ],
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: alloc.percentage / 100,
                          minHeight: 5,
                          backgroundColor: c.surfaceTinted,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StepView extends StatelessWidget {
  final Widget child;
  const _StepView({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [child],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: context.appColors.ink2));
  }
}

class _TypeToggle extends StatelessWidget {
  final String type;
  final void Function(String) onChanged;
  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: context.appColors.surfaceTinted,
          borderRadius: BorderRadius.circular(14)),
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
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: selected ? Colors.white : context.appColors.muted)),
      ),
    );
  }
}

class _TaskBanner extends StatelessWidget {
  Future<void> _open(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TaskSelectionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final auth = context.watch<AuthProvider>();
    if (auth.taskId == null) {
      return OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: const Text('Seleccionar tarea Bitrix'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(color: c.line, width: 1.5),
          foregroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? c.surfaceTinted
              : AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.task_alt_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auth.taskName ?? 'Tarea seleccionada',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.ink),
                      overflow: TextOverflow.ellipsis),
                  Text('ID: ${auth.taskId}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primary)),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, size: 16, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? displayValue;
  final Color? accent;
  final bool optional;

  const _MoneyTile({
    required this.label,
    this.controller,
    this.displayValue,
    this.accent,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(label.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: c.muted,
                        letterSpacing: 0.4),
                    overflow: TextOverflow.ellipsis),
              ),
              if (optional)
                Text(' · opc',
                    style: TextStyle(fontSize: 9, color: c.muted2)),
            ],
          ),
          const SizedBox(height: 4),
          if (controller != null)
            TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: accent ?? c.ink),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            )
          else
            Text(displayValue ?? '—',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: accent ?? c.ink)),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

// ─── Item widgets (lógica sin cambios) ───────────────────────────────────────

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
      : descripCtrl =
            TextEditingController(text: m['descrip']?.toString() ?? ''),
        unitCtrl = TextEditingController(
            text: m['unitOfMeasure']?.toString() ?? ''),
        quantityCtrl = TextEditingController(
            text: m['quantity']?.toString() ?? '1'),
        priceCtrl = TextEditingController(
            text: m['unitPrice']?.toString() ?? ''),
        _ocrSubtotal = m['subtotal'] != null
            ? (m['subtotal'] as num).toDouble()
            : null;

  double get subtotal {
    final calculated = (double.tryParse(quantityCtrl.text) ?? 0) *
        (double.tryParse(priceCtrl.text) ?? 0);
    if (calculated == 0 && _ocrSubtotal != null && _ocrSubtotal! > 0) {
      return _ocrSubtotal!;
    }
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
  const _ItemTile(
      {required this.item,
      required this.index,
      required this.onRemove,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Item ${index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.muted)),
              const Spacer(),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded,
                    color: AppTheme.error, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
              controller: item.descripCtrl,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                  labelText: 'Descripción', isDense: true)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.quantityCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                      labelText: 'Cantidad', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: item.priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                      labelText: 'Precio unitario', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.unitCtrl,
            decoration: const InputDecoration(
                labelText: 'Unidad de medida', isDense: true),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Subtotal: S/ ${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
