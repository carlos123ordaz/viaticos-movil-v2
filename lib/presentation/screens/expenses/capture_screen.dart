import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/services/expense_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();

  String? _filePath;
  bool _isPdf = false;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _extractedData;
  bool _showResult = false;

  Future<void> _pickCamera() async {
    final result = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
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
    final result = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
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
      final items = (data['items'] as List<dynamic>? ?? []).map((item) => <String, dynamic>{
        'descrip': item['descrip'] ?? item['description'] ?? '',
        'unitOfMeasure': item['unitOfMeasure'] ?? '',
        'unitPrice': item['unitPrice'],
        'quantity': item['quantity'],
        'subtotal': item['subtotal'],
      }).toList();
      setState(() {
        _extractedData = {...data, 'descrip': data['descrip'] ?? data['description'] ?? '', 'items': items};
        _showResult = true;
        _isProcessing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al procesar el archivo. Verifica tu conexión e intenta de nuevo.';
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFAFAFE),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            title: const Text('Escanear Comprobante',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF374151)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Opciones de captura
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Seleccionar fuente',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _SourceButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Cámara',
                          color: const Color(0xFF4F46E5),
                          onTap: _pickCamera,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _SourceButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Galería',
                          color: const Color(0xFF059669),
                          onTap: _pickGallery,
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _SourceButton(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'PDF',
                          color: const Color(0xFFDC2626),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: _isPdf
                            ? Container(
                                height: 200,
                                color: const Color(0xFFF9FAFB),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.picture_as_pdf_rounded, size: 64, color: Color(0xFFDC2626)),
                                    SizedBox(height: 12),
                                    Text('Archivo PDF seleccionado', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )
                            : Image.file(File(_filePath!), height: 280, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(_isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                                size: 16, color: const Color(0xFF6B7280)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _filePath!.split('/').last,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _filePath = null;
                                _extractedData = null;
                                _error = null;
                              }),
                              child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Placeholder
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text('Selecciona una fuente arriba', style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
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
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              // Botón OCR
              SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton.icon(
                  onPressed: (_filePath == null || _isProcessing) ? null : _processOcr,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    disabledBackgroundColor: const Color(0xFFC7C7CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.document_scanner_rounded, size: 20),
                  label: Text(_isProcessing ? 'Procesando OCR...' : 'Procesar con OCR',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('El OCR extrae automáticamente los datos del comprobante',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        // Modal: Resultado OCR
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
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 36, height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                              if (_extractedData!['total'] != null)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('Total detectado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_moneda(_extractedData!['currencyCode'] as String?)} ${((_extractedData!['total'] as num?) ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                      ),
                                    ],
                                  ),
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
                                    if (_extractedData!['businessName'] != null)
                                      _ResultField('Razón Social', _extractedData!['businessName'] as String),
                                    if (_extractedData!['ruc'] != null)
                                      _ResultField('RUC', _extractedData!['ruc'] as String),
                                    if (_extractedData!['address'] != null)
                                      _ResultField('Dirección', _extractedData!['address'] as String),
                                    if (_extractedData!['descrip'] != null && (_extractedData!['descrip'] as String).isNotEmpty)
                                      _ResultField('Descripción', _extractedData!['descrip'] as String),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _showResult = false),
                                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                  label: const Text('Volver'),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _confirmAndNavigate,
                                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                                  label: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w700)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  const _SourceButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
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
