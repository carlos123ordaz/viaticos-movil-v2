import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/expense_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();

  String? _filePath;
  bool _isPdf = false;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _extractedData;
  bool _showResult = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final result =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
    if (result != null) {
      setState(() {
        _filePath = result.path;
        _isPdf = false;
        _error = null;
        _extractedData = null;
        _showResult = false;
      });
    }
  }

  Future<void> _pickGallery() async {
    final result =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (result != null) {
      setState(() {
        _filePath = result.path;
        _isPdf = false;
        _error = null;
        _extractedData = null;
        _showResult = false;
      });
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
        _isPdf = true;
        _error = null;
        _extractedData = null;
        _showResult = false;
      });
    }
  }

  Future<void> _processOcr() async {
    if (_filePath == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final service = context.read<ExpenseService>();
      final data = await service.captureVoucher(_filePath!);
      if (!mounted) return;
      final items =
          (data['items'] as List<dynamic>? ?? []).map((item) => <String, dynamic>{
                'descrip': item['descrip'] ?? item['description'] ?? '',
                'unitOfMeasure': item['unitOfMeasure'] ?? '',
                'unitPrice': item['unitPrice'],
                'quantity': item['quantity'],
                'subtotal': item['subtotal'],
              }).toList();
      setState(() {
        _extractedData = {
          ...data,
          'descrip': data['descrip'] ?? data['description'] ?? '',
          'items': items,
        };
        _showResult = true;
        _isProcessing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Error al procesar el archivo. Verifica tu conexión e intenta de nuevo.';
        _isProcessing = false;
      });
    }
  }

  void _confirmAndNavigate() {
    if (_extractedData == null) return;
    final data = Map<String, dynamic>.from(_extractedData!);
    if (_filePath != null) data['scannedFilePath'] = _filePath;
    setState(() => _showResult = false);
    context.pushReplacement('/add-expense', extra: {'prefillData': data});
  }

  String _moneda(String? code) {
    if (code == 'USD') return '\$';
    if (code == 'EUR') return '€';
    return 'S/';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            backgroundColor: c.surface,
            elevation: 0,
            surfaceTintColor: c.surface,
            title: Text('Escanear Comprobante',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.ink)),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: c.ink),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Fuentes de captura
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seleccionar fuente',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.ink)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _SourceButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Cámara',
                          color: AppTheme.primary,
                          onTap: _pickCamera,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _SourceButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Galería',
                          color: AppTheme.secondary,
                          onTap: _pickGallery,
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _SourceButton(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'PDF',
                          color: AppTheme.coral,
                          onTap: _pickPdf,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Preview
              if (_filePath != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(20)),
                        child: _isPdf
                            ? Container(
                                height: 200,
                                color: c.surfaceTinted,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded,
                                        size: 64, color: AppTheme.coral),
                                    const SizedBox(height: 12),
                                    Text('Archivo PDF seleccionado',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: c.muted,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )
                            : Image.file(File(_filePath!),
                                height: 280,
                                width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                                _isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.image_rounded,
                                size: 16,
                                color: c.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _filePath!.split('/').last,
                                style: TextStyle(
                                    fontSize: 13, color: c.muted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _filePath = null;
                                _extractedData = null;
                                _error = null;
                              }),
                              child: const Icon(Icons.close_rounded,
                                  size: 18, color: AppTheme.coral),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: c.surfaceTinted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.line, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 48, color: c.line),
                      const SizedBox(height: 12),
                      Text('Selecciona una fuente arriba',
                          style:
                              TextStyle(fontSize: 14, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Error
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 18, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              // Botón OCR
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed:
                      (_filePath == null || _isProcessing) ? null : _processOcr,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: c.line,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.document_scanner_rounded, size: 20),
                  label: const Text('Procesar con OCR',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                    'El OCR extrae automáticamente los datos del comprobante',
                    style: TextStyle(fontSize: 12, color: c.muted),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),

        // ── Overlay: Procesando ─────────────────────────────────────────────
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.55),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 40,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedBuilder(
                          animation: _rotateCtrl,
                          builder: (_, child) => Transform.rotate(
                            angle: _rotateCtrl.value * 2 * math.pi,
                            child: child,
                          ),
                          child: const Icon(Icons.document_scanner_rounded,
                              size: 38, color: AppTheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Procesando comprobante',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: c.ink),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Extrayendo datos automáticamente...',
                        style: TextStyle(fontSize: 13, color: c.muted),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: c.surfaceTinted,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Modal: Resultado OCR ────────────────────────────────────────────
        if (_showResult && _extractedData != null)
          GestureDetector(
            onTap: () => setState(() => _showResult = false),
            child: Container(
              color: Colors.black54,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.88),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: c.line,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                    color: AppTheme.secondaryContainer,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded,
                                    color: AppTheme.secondary, size: 28),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                  child: Text('Comprobante procesado',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: c.ink))),
                              const SizedBox(height: 4),
                              Center(
                                  child: Text(
                                      'Revisa los datos y confirma para continuar',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: c.muted))),
                              const SizedBox(height: 20),
                              if (_extractedData!['total'] != null)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AppTheme.secondary
                                            .withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('Total detectado',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.secondary)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_moneda(_extractedData!['currencyCode'] as String?)} ${((_extractedData!['total'] as num?) ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.secondary),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: c.surfaceTinted,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: c.line),
                                  boxShadow: AppTheme.cardShadow,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_extractedData!['businessName'] != null)
                                      _ResultField('Razón Social',
                                          _extractedData!['businessName']
                                              as String),
                                    if (_extractedData!['ruc'] != null)
                                      _ResultField(
                                          'RUC', _extractedData!['ruc'] as String),
                                    if (_extractedData!['address'] != null)
                                      _ResultField('Dirección',
                                          _extractedData!['address'] as String),
                                    if (_extractedData!['descrip'] != null &&
                                        (_extractedData!['descrip'] as String)
                                            .isNotEmpty)
                                      _ResultField('Descripción',
                                          _extractedData!['descrip'] as String),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 12, 20,
                              20 + MediaQuery.of(context).padding.bottom),
                          decoration: BoxDecoration(
                              border: Border(
                                  top: BorderSide(color: c.line))),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _showResult = false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(
                                        color: c.line, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  child: Text('Volver',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: c.ink)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _confirmAndNavigate,
                                  icon: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 20),
                                  label: const Text('Continuar',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
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
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.muted,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.ink)),
        ],
      ),
    );
  }
}
