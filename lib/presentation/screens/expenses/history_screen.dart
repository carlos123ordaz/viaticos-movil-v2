import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/bitrix_task_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/bitrix_task_service.dart';
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
      final finalized = await context.read<ExpenseReportService>().getFinalizationState(taskId);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(width: 16),
              const Expanded(child: Text('Procesando comprobante...')),
            ]),
            const SizedBox(height: 8),
            Text(
              'Esto puede tardar unos segundos',
              style: TextStyle(fontSize: 12, color: ctx.appColors.muted),
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
    showModalBottomSheet<_CaptureSource>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        final cs = ctx.appColors;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 28 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nueva rendición',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.surfaceTinted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: cs.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Elige cómo quieres registrarlo.',
                  style: TextStyle(fontSize: 14, color: cs.muted),
                ),
              ),
              const SizedBox(height: 20),
              _MethodCard(
                color: AppTheme.primary,
                tint: AppTheme.primaryContainer,
                icon: Icons.camera_alt_rounded,
                title: 'Escanear comprobante',
                desc: 'Toma foto o sube PDF · extraemos los datos con IA.',
                badge: 'Más rápido',
                onTap: () => Navigator.pop(ctx, _CaptureSource.camera),
              ),
              const SizedBox(height: 10),
              _MethodCard(
                color: AppTheme.violet,
                tint: AppTheme.violetTint,
                icon: Icons.mic_rounded,
                title: 'Dictar por voz',
                desc: '"Almuerzo en La Lucha, 45 soles, con boleta"',
                onTap: () { Navigator.pop(ctx); context.push('/voice-expense'); },
              ),
              const SizedBox(height: 10),
              _MethodCard(
                color: cs.ink2,
                tint: cs.surfaceTinted,
                icon: Icons.edit_note_rounded,
                title: 'Llenar manualmente',
                desc: 'Ingresa todos los datos paso a paso.',
                onTap: () { Navigator.pop(ctx); context.push('/add-expense'); },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SmallMethodCard(
                      color: AppTheme.sky,
                      tint: AppTheme.skyTint,
                      icon: Icons.photo_library_rounded,
                      label: 'Galería',
                      onTap: () => Navigator.pop(ctx, _CaptureSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallMethodCard(
                      color: AppTheme.error,
                      tint: AppTheme.errorContainer,
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      onTap: () => Navigator.pop(ctx, _CaptureSource.pdf),
                    ),
                  ),
                ],
              ),
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
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'Mis Rendiciones',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _RichSummaryHeader(),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            )
                          : const Icon(Icons.flag_outlined, size: 16, color: Colors.white70),
                      label: const Text(
                        'Finalizar',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
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
                            decoration: const BoxDecoration(
                              color: AppTheme.yellow,
                              shape: BoxShape.circle,
                            ),
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
              color: AppTheme.primary,
              child: CustomScrollView(
                slivers: [
                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: provider.setSearch,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Buscar rendiciones...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.appColors.muted),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    provider.setSearch('');
                                  },
                                  icon: Icon(Icons.clear_rounded, size: 18, color: context.appColors.muted),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  // Report finalized banner
                  if (_isReportFinalized)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.secondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Esta tarea ya fue finalizada. Ya no puedes agregar más rendiciones.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Active task banner
                  SliverToBoxAdapter(
                    child: Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.taskId == null) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: _openTaskSelection,
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.task_alt_rounded, color: AppTheme.primary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.taskName ?? 'Tarea: ${auth.taskId}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Category filter chips
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
                              onSelected: () => provider.setCategoryFilter(cat),
                              color: getCategoryColor(cat),
                              bg: getCategoryBg(cat),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  // Main content
                  if (provider.isLoading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ShimmerCard(height: 80, borderRadius: BorderRadius.circular(20)),
                        ),
                        childCount: 5,
                      ),
                    )
                  else if (provider.expenses.isEmpty)
                    SliverFillRemaining(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: provider.search.isNotEmpty ? 'Sin resultados' : 'No hay rendiciones aún',
                        subtitle: provider.search.isNotEmpty
                            ? 'Intenta con otro término de búsqueda'
                            : 'Toca el botón + para agregar tu primera rendición',
                        action: provider.search.isEmpty
                            ? ElevatedButton.icon(
                                onPressed: _showAddOptions,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Agregar rendición'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              )
                            : null,
                      ),
                    ),
                  // Selection mode banner
                  if (provider.isSelectionMode)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${provider.selectedCount} de ${provider.expenses.length} seleccionados',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => provider.selectAll(provider.expenses.map((e) => e.id).toList()),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Todos', style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
                            ),
                            TextButton(
                              onPressed: provider.exitSelectionMode,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Cancelar', style: TextStyle(fontSize: 12, color: AppTheme.secondary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!provider.isLoading && provider.expenses.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final expense = provider.expenses[i];
                            final isSelected = provider.selectedIds.contains(expense.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: provider.isSelectionMode
                                  ? _SelectableExpenseCard(
                                      expense: expense,
                                      isSelected: isSelected,
                                      onTap: () => provider.toggleSelection(expense.id),
                                    )
                                  : GestureDetector(
                                      onLongPress: () => provider.enterSelectionMode(expense.id),
                                      child: ExpenseCard(
                                        expense: expense,
                                        onTap: () => context.push('/expense/${expense.id}'),
                                        onDelete: () => _delete(expense),
                                      ),
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
      floatingActionButton: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (_isReportFinalized) return const SizedBox.shrink();
          if (provider.expenses.isEmpty && !provider.isLoading) return const SizedBox.shrink();
          if (provider.isSelectionMode) {
            return FloatingActionButton.extended(
              onPressed: provider.selectedCount > 0
                  ? () => _showAssignTaskSheet(provider)
                  : null,
              backgroundColor: AppTheme.secondary,
              icon: const Icon(Icons.task_alt_rounded),
              label: Text(
                'Asignar tarea · ${provider.selectedCount}',
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700),
              ),
            );
          }
          return FloatingActionButton.extended(
            onPressed: _showAddOptions,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Nueva rendición',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700),
            ),
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

  Future<void> _showAssignTaskSheet(ExpenseProvider provider) async {
    final count = provider.selectedCount;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _AssignTaskSheet(
        selectedCount: count,
        onAssign: (taskId) async {
          Navigator.pop(ctx);
          final ok = await provider.assignTask(taskId);
          if (!mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$count rendición(es) asignada(s) correctamente')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error al asignar la tarea')),
            );
          }
        },
      ),
    );
  }
}

// ── Rich Hero Header ──────────────────────────────────────────────────────────

class _RichSummaryHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ExpenseProvider>(
      builder: (context, auth, provider, _) {
        final name = auth.user?.name?.split(' ').first ?? 'Usuario';
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B5BFF), Color(0xFF2F49D9)],
            ),
          ),
          child: Stack(
            children: [
              // Deco circle top-right
              Positioned(
                top: -40,
                right: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x2EFFD66B),
                  ),
                ),
              ),
              // Deco square
              Positioned(
                bottom: 50,
                right: 90,
                child: Transform.rotate(
                  angle: 0.35,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0x4D7FB3FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, $name 👋',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.currency(provider.monthAmount),
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${provider.expenses.length} rendiciones',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          Text(
                            'este mes',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;
  final Color? bg;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primary;
    final activeBg = bg ?? AppTheme.primaryContainer;
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeBg : c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? activeColor.withOpacity(0.4) : c.line,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? activeColor : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Method Cards ──────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final Color color;
  final Color tint;
  final IconData icon;
  final String title;
  final String desc;
  final String? badge;
  final VoidCallback onTap;

  const _MethodCard({
    required this.color,
    required this.tint,
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? c.surfaceTinted : tint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F0E1330),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.yellow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1B02),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallMethodCard extends StatelessWidget {
  final Color color;
  final Color tint;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallMethodCard({
    required this.color,
    required this.tint,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? context.appColors.surfaceTinted : tint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OCR Result Sheet ──────────────────────────────────────────────────────────

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
    final c = context.appColors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44, height: 5,
            decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(3)),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shrinkWrap: true,
              children: [
                Container(
                  width: 56, height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.check_rounded, color: AppTheme.secondary, size: 28),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Comprobante procesado',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Revisa los datos y confirma para continuar',
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                ),
                const SizedBox(height: 20),
                if (data['total'] != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      const Text(
                        'Total detectado',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.secondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_moneda(data['currencyCode'] as String?)} ${((data['total'] as num?) ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondary,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ]),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
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
          Builder(builder: (ctx) => Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: ctx.appColors.line))),
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
                  label: const Text('Continuar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          )),
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
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Finalize Dialog ───────────────────────────────────────────────────────────

class _FinalizeDialog extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String userName;

  const _FinalizeDialog({required this.expenses, required this.userName});

  Color _catColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.alimentacion: return AppTheme.coral;
      case ExpenseCategory.transporte:   return AppTheme.sky;
      case ExpenseCategory.alojamiento:  return AppTheme.violet;
      case ExpenseCategory.compras:      return AppTheme.mint;
      case ExpenseCategory.otros:        return AppTheme.primary;
    }
  }

  String _monthName(int month) {
    const months = ['enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Builder(
        builder: (ctx) {
          final c = ctx.appColors;
          return ConstrainedBox(
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
                        color: AppTheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(Icons.shield_outlined, size: 28, color: AppTheme.secondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Finalizar rendición',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (expenses.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESUMEN',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...byCurrency.entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Gastado (${entry.key})', style: TextStyle(fontSize: 13, color: c.muted)),
                                  Text(
                                    Formatters.currency(entry.value, currency: entry.key),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.error),
                                  ),
                                ],
                              ),
                            )),
                            Divider(color: c.line, height: 20),
                            Text(
                              'POR CATEGORÍA',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
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
                                      child: Text(catEntry.key.label, style: TextStyle(fontSize: 13, color: c.muted)),
                                    ),
                                    Text(
                                      Formatters.currency(currEntry.value, currency: currEntry.key),
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
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
                        color: AppTheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            color: c.ink2,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'yo '),
                            TextSpan(
                              text: userName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal, color: AppTheme.secondary),
                            ),
                            const TextSpan(text: ' En fe de la verdad firmo la presente Declaración Jurada que todos los datos son veraces '),
                            TextSpan(
                              text: dateStr,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal, color: AppTheme.secondary),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Una vez finalizada, no podrás agregar más rendiciones a esta tarea.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
        },
      ),
    );
  }
}

// ── Selectable Expense Card ───────────────────────────────────────────────────

class _SelectableExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableExpenseCard({
    required this.expense,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final catColor = getCategoryColor(expense.category);
    final catBg = getCategoryBg(expense.category);
    final catIcon = getCategoryIcon(expense.category);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryContainer : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.secondary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [] : AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppTheme.secondary : c.muted2,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expense.category.label,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                Formatters.currency(expense.amount, currency: expense.currency),
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Assign Task Sheet ─────────────────────────────────────────────────────────

class _AssignTaskSheet extends StatefulWidget {
  final int selectedCount;
  final Future<void> Function(String taskId) onAssign;

  const _AssignTaskSheet({required this.selectedCount, required this.onAssign});

  @override
  State<_AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends State<_AssignTaskSheet> {
  List<BitrixTaskModel> _tasks = [];
  bool _loading = true;
  bool _assigning = false;
  String _search = '';
  BitrixTaskModel? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final service = context.read<BitrixTaskService>();
      final tasks = await service.getLastTasks();
      if (mounted) setState(() { _tasks = tasks; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<BitrixTaskModel> get _filtered {
    if (_search.isEmpty) return _tasks;
    final q = _search.toLowerCase();
    return _tasks.where((t) =>
      t.title.toLowerCase().contains(q) || t.id.contains(q)).toList();
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    setState(() => _assigning = true);
    await widget.onAssign(_selected!.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asignar tarea',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        '${widget.selectedCount} rendición(es) seleccionada(s)',
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: c.surfaceTinted, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.close_rounded, size: 18, color: c.muted),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Buscar tarea...',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.muted),
              ),
            ),
          ),
          Flexible(
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ))
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final task = _filtered[i];
                      final isSelected = _selected?.id == task.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = task),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.secondaryContainer : c.surfaceTinted,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.secondary : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: isSelected ? AppTheme.secondary : c.muted2,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppTheme.secondary : c.ink,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '#${task.id}',
                                        style: TextStyle(fontSize: 11, color: c.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_selected == null || _assigning) ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _assigning
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _selected == null ? 'Selecciona una tarea' : 'Confirmar asignación',
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


enum _CaptureSource { camera, gallery, pdf }
