import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/expense_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/expense_card.dart';
import '../../../data/services/expense_report_service.dart';
import 'task_selection_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isReportFinalized = false;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final taskId = auth.taskId;
    await context.read<ExpenseProvider>().load(taskId: taskId);
    if (taskId != null && mounted) {
      final finalized = await context
          .read<ExpenseReportService>()
          .getFinalizationState(taskId);
      if (mounted) setState(() => _isReportFinalized = finalized);
    } else if (mounted) {
      setState(() => _isReportFinalized = false);
    }
  }

  Future<void> _openTaskSelection() async {
    final prevTaskId = context.read<AuthProvider>().taskId;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TaskSelectionScreen()),
    );
    if (!mounted) return;
    final newTaskId = context.read<AuthProvider>().taskId;
    if (newTaskId != prevTaskId) _load();
  }

  Future<void> _finalize() async {
    final auth = context.read<AuthProvider>();
    final taskId = auth.taskId;
    final userId = auth.user?.id;
    if (taskId == null || userId == null) return;

    final expenses = context.read<ExpenseProvider>().expenses;
    final userName = auth.user?.name ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FinalizeDialog(expenses: expenses, userName: userName),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isFinalizing = true);
    try {
      await context.read<ExpenseReportService>().finalizeReport(taskId, userId);
      if (mounted) setState(() => _isReportFinalized = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo finalizar la rendición')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  Future<void> _captureFromCamera() async {
    final result = await _picker.pickImage(source: ImageSource.camera, imageQuality: 65, maxWidth: 1200);
    if (result != null && mounted) await _processOcr(result.path);
  }

  Future<void> _captureFromGallery() async {
    final result = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 65, maxWidth: 1200);
    if (result != null && mounted) await _processOcr(result.path);
  }

  Future<void> _captureFromPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result?.files.single.path != null && mounted) {
      await _processOcr(result!.files.single.path!);
    }
  }

  Future<void> _processOcr(String filePath) async {
    if (!mounted) return;

    final cancelToken = CancelToken();
    bool dialogOpen = true;

    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Procesando comprobante...')),
            ]),
            SizedBox(height: 8),
            Text(
              'Esto puede tardar unos segundos',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelToken.cancel();
              dialogOpen = false;
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ).then((_) => dialogOpen = false);

    try {
      final service = context.read<ExpenseService>();
      final data = await service.captureVoucher(filePath, cancelToken: cancelToken);
      if (!mounted) return;
      closeDialog();
      final items = (data['items'] as List<dynamic>? ?? []).map((item) => <String, dynamic>{
        'descrip': item['descrip'] ?? item['description'] ?? '',
        'unitOfMeasure': item['unitOfMeasure'] ?? '',
        'unitPrice': item['unitPrice'],
        'quantity': item['quantity'],
        'subtotal': item['subtotal'],
      }).toList();
      final extractedData = <String, dynamic>{
        ...data,
        'descrip': data['descrip'] ?? data['description'] ?? '',
        'items': items,
        'scannedFilePath': filePath,
      };
      _showOcrResult(extractedData);
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && CancelToken.isCancel(e)) return;
      closeDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al procesar el archivo. Verifica tu conexión e intenta de nuevo.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _showOcrResult(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _OcrResultSheet(
        data: data,
        onConfirm: () {
          Navigator.pop(ctx);
          context.push('/add-expense', extra: {'prefillData': data});
        },
        onBack: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showAddOptions() {
    final auth = context.read<AuthProvider>();
    if (auth.taskId == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tarea requerida'),
          content: const Text(
              'Debes seleccionar una tarea antes de registrar un gasto.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openTaskSelection();
              },
              child: const Text('Seleccionar tarea'),
            ),
          ],
        ),
      );
      return;
    }
    showModalBottomSheet<_CaptureSource>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Text('Nuevo gasto', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Elige cómo registrar el gasto', style: TextStyle(fontSize: 13, color: colors.outline)),
              const SizedBox(height: 14),
              _AddOption(icon: Icons.edit_note_rounded, color: colors.primary, label: 'Manual',
                  subtitle: 'Ingresa los datos manualmente',
                  onTap: () { Navigator.pop(ctx); context.push('/add-expense'); }),
              const SizedBox(height: 8),
              _AddOption(icon: Icons.mic_rounded, color: const Color(0xFF4F46E5), label: 'Por voz',
                  subtitle: 'Dicta tu gasto y la IA lo procesa',
                  onTap: () { Navigator.pop(ctx); context.push('/voice-expense'); }),
              const SizedBox(height: 8),
              _AddOption(icon: Icons.camera_alt_rounded, color: const Color(0xFF059669), label: 'Cámara',
                  subtitle: 'Toma una foto del comprobante',
                  onTap: () => Navigator.pop(ctx, _CaptureSource.camera)),
              const SizedBox(height: 8),
              _AddOption(icon: Icons.photo_library_rounded, color: const Color(0xFF0891B2), label: 'Galería',
                  subtitle: 'Elige una imagen de tu galería',
                  onTap: () => Navigator.pop(ctx, _CaptureSource.gallery)),
              const SizedBox(height: 8),
              _AddOption(icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFDC2626), label: 'PDF',
                  subtitle: 'Sube un archivo PDF del comprobante',
                  onTap: () => Navigator.pop(ctx, _CaptureSource.pdf)),
            ],
          ),
        );
      },
    ).then((source) {
      if (source == null || !mounted) return;
      switch (source) {
        case _CaptureSource.camera:  _captureFromCamera();
        case _CaptureSource.gallery: _captureFromGallery();
        case _CaptureSource.pdf:     _captureFromPdf();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Mis Gastos',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _SummaryHeader(),
            ),
            actions: [
              if (!_isReportFinalized)
                Consumer<AuthProvider>(
                  builder: (_, auth, __) {
                    if (auth.taskId == null) return const SizedBox.shrink();
                    return TextButton.icon(
                      onPressed: _isFinalizing ? null : _finalize,
                      icon: _isFinalizing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white70))
                          : const Icon(Icons.flag_outlined,
                              size: 16, color: Colors.white70),
                      label: const Text('Finalizar',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => IconButton(
                  onPressed: _openTaskSelection,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.task_alt_rounded, color: Colors.white),
                      if (auth.taskId != null)
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Seleccionar tarea',
                ),
              ),
            ],
          ),
        ],
        body: Consumer<ExpenseProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: _load,
              color: colors.primary,
              child: CustomScrollView(
                slivers: [
                  // Barra de búsqueda
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: provider.setSearch,
                        decoration: InputDecoration(
                          hintText: 'Buscar gastos...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    provider.setSearch('');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  // Banner rendición finalizada
                  if (_isReportFinalized)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 16, color: Color(0xFF047857)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Esta tarea ya fue finalizada. Ya no puedes agregar más gastos.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Banner tarea activa
                  SliverToBoxAdapter(
                    child: Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.taskId == null) return const SizedBox.shrink();
                        final colors = Theme.of(context).colorScheme;
                        return GestureDetector(
                          onTap: _openTaskSelection,
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: colors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.task_alt_rounded,
                                    color: colors.primary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.taskName ?? 'Tarea: ${auth.taskId}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.primary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 16,
                                    color: colors.primary.withOpacity(0.7)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Filtros por categoría
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _FilterChip(
                            label: 'Todos',
                            selected: provider.categoryFilter == null,
                            onSelected: () => provider.setCategoryFilter(null),
                          ),
                          ...ExpenseCategory.values.map(
                            (cat) => _FilterChip(
                              label: cat.label,
                              selected: provider.categoryFilter == cat,
                              onSelected: () =>
                                  provider.setCategoryFilter(cat),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  // Contenido principal
                  if (provider.isLoading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ShimmerCard(
                              height: 80,
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        childCount: 5,
                      ),
                    )
                  else if (provider.expenses.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: provider.search.isNotEmpty
                            ? 'Sin resultados'
                            : 'No hay gastos aún',
                        subtitle: provider.search.isNotEmpty
                            ? 'Intenta con otro término de búsqueda'
                            : 'Toca el botón + para agregar tu primer gasto',
                        action: provider.search.isEmpty
                            ? ElevatedButton.icon(
                                onPressed: _showAddOptions,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Agregar gasto'),
                                style: ElevatedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                              )
                            : null,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final expense = provider.expenses[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ExpenseCard(
                                expense: expense,
                                onTap: () =>
                                    context.push('/expense/${expense.id}'),
                                onDelete: () => _delete(expense),
                              ),
                            );
                          },
                          childCount: provider.expenses.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.taskId == null || _isReportFinalized) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: _showAddOptions,
            child: const Icon(Icons.add_rounded),
          );
        },
      ),
    );
  }

  Future<void> _delete(ExpenseModel expense) async {
    final ok = await context.read<ExpenseProvider>().delete(expense.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${expense.description} eliminado'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }
}

class _SummaryHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 90, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
            ),
          ),
          child: Row(
            children: [
              _StatItem(
                label: 'Este mes',
                value: Formatters.currency(provider.monthAmount),
              ),
              Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withOpacity(0.3)),
              _StatItem(
                label: 'Total registrado',
                value: Formatters.currency(provider.totalAmount),
              ),
              Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withOpacity(0.3)),
              _StatItem(
                label: 'Gastos',
                value: provider.expenses.length.toString(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: colors.primaryContainer,
        checkmarkColor: colors.primary,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: selected ? colors.primary : colors.onSurface,
        ),
      ),
    );
  }
}

class _OcrResultSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _OcrResultSheet({required this.data, required this.onConfirm, required this.onBack});

  String _moneda(String? code) {
    if (code == 'USD') return '\$';
    if (code == 'EUR') return '€';
    return 'S/';
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shrinkWrap: true,
              children: [
                const CircleAvatar(
                  radius: 28, backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.check_rounded, color: Color(0xFF059669), size: 28),
                ),
                const SizedBox(height: 12),
                const Center(child: Text('Comprobante procesado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827)))),
                const SizedBox(height: 4),
                const Center(child: Text('Revisa los datos y confirma para continuar',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)))),
                const SizedBox(height: 20),
                if (data['total'] != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(children: [
                      const Text('Total detectado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                      const SizedBox(height: 4),
                      Text(
                        '${_moneda(data['currencyCode'] as String?)} ${((data['total'] as num?) ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                      ),
                    ]),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['businessName'] != null) _ResultField('Razón Social', data['businessName'] as String),
                      if (data['ruc'] != null) _ResultField('RUC', data['ruc'] as String),
                      if (data['address'] != null) _ResultField('Dirección', data['address'] as String),
                      if ((data['descrip'] as String?)?.isNotEmpty == true)
                        _ResultField('Descripción', data['descrip'] as String),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Volver'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ResultField extends StatelessWidget {
  final String label;
  final String value;
  const _ResultField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        ],
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _AddOption({required this.icon, required this.color, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

enum _CaptureSource { camera, gallery, pdf }

class _FinalizeDialog extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String userName;

  const _FinalizeDialog({required this.expenses, required this.userName});

  Color _catColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.alimentacion: return const Color(0xFFF87171);
      case ExpenseCategory.transporte:   return const Color(0xFF60A5FA);
      case ExpenseCategory.alojamiento:  return const Color(0xFFA78BFA);
      case ExpenseCategory.compras:      return const Color(0xFFFBBF24);
      case ExpenseCategory.otros:        return const Color(0xFF9CA3AF);
    }
  }

  String _monthName(int month) {
    const months = ['enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final byCurrency = <String, double>{};
    final byCat = <ExpenseCategory, Map<String, double>>{};
    for (final e in expenses) {
      byCurrency[e.currency] = (byCurrency[e.currency] ?? 0) + e.amount;
      byCat[e.category] ??= {};
      byCat[e.category]![e.currency] = (byCat[e.category]![e.currency] ?? 0) + e.amount;
    }

    final today = DateTime.now();
    final dateStr = '${today.day} de ${_monthName(today.month)} de ${today.year}';
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(Icons.shield_outlined, size: 28, color: Color(0xFF059669)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Finalizar rendición',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 16),

                    if (expenses.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RESUMEN',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                            const SizedBox(height: 10),
                            ...byCurrency.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Gastado (${entry.key})',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                  Text(Formatters.currency(entry.value, currency: entry.key),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC2626))),
                                ],
                              ),
                            )),
                            const Divider(color: Color(0xFFE5E7EB), height: 20),
                            const Text('POR CATEGORÍA',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
                            const SizedBox(height: 10),
                            ...byCat.entries.expand((catEntry) => catEntry.value.entries.map((currEntry) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: _catColor(catEntry.key),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(catEntry.key.label,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                    ),
                                    Text(
                                      Formatters.currency(currEntry.value, currency: currEntry.key),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827)),
                                    ),
                                  ],
                                ),
                              )
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF374151),
                              fontStyle: FontStyle.italic, height: 1.57),
                          children: [
                            const TextSpan(text: 'yo '),
                            TextSpan(
                              text: userName,
                              style: const TextStyle(fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.normal, color: Color(0xFF065F46)),
                            ),
                            const TextSpan(
                              text: ' En fe de la verdad firmo la presente Declaración Jurada'
                                  ' que todos los datos son veraces ',
                            ),
                            TextSpan(
                              text: dateStr,
                              style: const TextStyle(fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.normal, color: Color(0xFF065F46)),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Una vez finalizada, no podrás agregar más gastos a esta tarea.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirmar'),
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
}
