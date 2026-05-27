import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/theme/app_theme.dart';
import '../../../data/services/expense_service.dart';

const _kTips = [
  'Menciona el monto total del gasto',
  'Indica la moneda si no es soles (ej: "en dólares")',
  'Describe qué compraste o el servicio',
  'Agrega el RUC si lo tienes',
  'Puedes mencionar varios items con cantidades',
];

const _kExamples = [
  (icon: Icons.restaurant_rounded, color: Color(0xFFF87171), title: 'Alimentación',
   text: '"Almuerzo en restaurante El Buen Sabor por 35 soles, RUC 20123456789"'),
  (icon: Icons.directions_car_rounded, color: Color(0xFF60A5FA), title: 'Movilidad',
   text: '"Taxi del aeropuerto al hotel, 25 soles"'),
  (icon: Icons.hotel_rounded, color: Color(0xFFA78BFA), title: 'Hospedaje',
   text: '"Hotel San Martín, 2 noches a 150 soles cada una, total 300 soles"'),
  (icon: Icons.shopping_cart_rounded, color: Color(0xFF34D399), title: 'Compras',
   text: '"Compra de 3 cascos de seguridad a 45 soles, total 135 en dólares"'),
  (icon: Icons.receipt_long_rounded, color: Color(0xFFFBBF24), title: 'Con detalles',
   text: '"Cena, 2 platos a 65 soles y 2 bebidas a 15 soles, total 160 con IGV, RUC 20987654321"'),
];

class VoiceExpenseScreen extends StatefulWidget {
  const VoiceExpenseScreen({super.key});

  @override
  State<VoiceExpenseScreen> createState() => _VoiceExpenseScreenState();
}

class _VoiceExpenseScreenState extends State<VoiceExpenseScreen>
    with TickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  final _textCtrl = TextEditingController();

  bool _initialized = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _extractedData;
  bool _showResult = false;
  bool _showGuide = false;

  late AnimationController _pulseCtrl;
  late AnimationController _wave1Ctrl;
  late AnimationController _wave2Ctrl;
  late AnimationController _wave3Ctrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _wave1Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _wave2Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _wave3Ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _initialized = await _speech.initialize(
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo reconocer la voz. Intenta de nuevo.';
          _isListening = false;
        });
        _stopAnimations();
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (!mounted) return;
          setState(() => _isListening = false);
          _stopAnimations();
        }
      },
    );
  }

  void _startAnimations() {
    _pulseCtrl.repeat(reverse: true);
    _wave1Ctrl.repeat();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _wave2Ctrl.repeat();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _wave3Ctrl.repeat();
    });
  }

  void _stopAnimations() {
    for (final c in [_pulseCtrl, _wave1Ctrl, _wave2Ctrl, _wave3Ctrl]) {
      c.stop();
      c.reset();
    }
  }

  Future<void> _toggleListening() async {
    if (!_initialized) {
      await _initSpeech();
      if (!_initialized) {
        setState(() => _error = 'Micrófono no disponible en este dispositivo');
        return;
      }
    }
    if (_isListening) {
      await _speech.stop();
      _stopAnimations();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _error = null;
        _isListening = true;
      });
      _startAnimations();
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          _textCtrl.text = result.recognizedWords;
          setState(() {});
        },
        localeId: 'es_PE',
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );
    }
  }

  Future<void> _process() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final service = context.read<ExpenseService>();
      final data = await service.voiceToExpense(text);
      if (!mounted) return;
      if (data['isValid'] != true) {
        setState(() {
          _error = (data['errorMessage'] as String?) ?? 'No se pudo interpretar como gasto válido.';
          _isProcessing = false;
        });
        return;
      }
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
    } catch (e) {
      if (!mounted) return;
      String msg = 'Error al procesar. Verifica tu conexión e intenta de nuevo.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          msg = 'El servidor tardó demasiado en responder. Intenta de nuevo en unos segundos.';
        } else if (e.response?.data is Map) {
          final serverMsg = (e.response!.data as Map)['message']?.toString();
          if (serverMsg != null) msg = serverMsg;
        }
        debugPrint('voiceToExpense error: $e — response: ${e.response?.data}');
      }
      setState(() {
        _error = msg;
        _isProcessing = false;
      });
    }
  }

  void _confirmAndNavigate() {
    if (_extractedData == null) return;
    final data = Map<String, dynamic>.from(_extractedData!);
    setState(() => _showResult = false);
    context.pushReplacement('/add-expense', extra: {'prefillData': data});
  }

  void _resetState() {
    _textCtrl.clear();
    setState(() {
      _extractedData = null;
      _error = null;
      _showResult = false;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _wave1Ctrl.dispose();
    _wave2Ctrl.dispose();
    _wave3Ctrl.dispose();
    super.dispose();
  }

  Widget _wave(AnimationController ctrl, double size) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Opacity(
        opacity: (1 - ctrl.value) * 0.4,
        child: Transform.scale(
          scale: 1 + ctrl.value,
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.violet, width: 2),
            ),
          ),
        ),
      ),
    );
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
            title: Text('Gasto por Voz',
                style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: c.ink2),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                onPressed: () => setState(() => _showGuide = true),
                icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF4F46E5)),
              ),
            ],
          ),
          body: Column(
            children: [
              // Banner instrucción
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.violetTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.violet.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic_rounded, size: 18, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Dicta tu gasto con el monto, categoría y detalles',
                          style: TextStyle(fontSize: 13, color: AppTheme.primaryDark, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              // Transcripción
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Descripción del gasto',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink2)),
                        if (_textCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: _resetState,
                            child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _textCtrl,
                      maxLines: 4,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ej: "Almuerzo en restaurante por 45 soles"',
                        hintStyle: TextStyle(color: c.muted2),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(fontSize: 15, color: c.ink),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_isListening) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text('Escuchando...', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Error
              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              // Micrófono
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220, height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isListening) ...[
                              _wave(_wave1Ctrl, 140),
                              _wave(_wave2Ctrl, 180),
                              _wave(_wave3Ctrl, 220),
                            ],
                            ScaleTransition(
                              scale: _pulseAnim,
                              child: GestureDetector(
                                onTap: _toggleListening,
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: _isListening ? AppTheme.error : AppTheme.violet,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isListening ? AppTheme.error : AppTheme.violet).withOpacity(0.3),
                                        blurRadius: 12, offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                    color: Colors.white, size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isListening ? 'Toca para detener' : 'Toca para hablar',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              // Botón Procesar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton.icon(
                    onPressed: (_textCtrl.text.trim().isEmpty || _isProcessing) ? null : _process,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      disabledBackgroundColor: const Color(0xFFC7C7CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(_isProcessing ? 'Procesando...' : 'Procesar con IA',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Modal: Guía
        if (_showGuide)
          GestureDetector(
            onTap: () => setState(() => _showGuide = false),
            child: Container(
              color: Colors.black54,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 36, height: 4,
                          decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 12),
                        const CircleAvatar(
                          radius: 28, backgroundColor: Color(0xFFEEF2FF),
                          child: Icon(Icons.mic_outlined, color: Color(0xFF4F46E5), size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text('¿Cómo dictar tu gasto?',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink)),
                        const SizedBox(height: 4),
                        Text('Sigue estos ejemplos para mejores resultados',
                            style: TextStyle(fontSize: 14, color: c.muted)),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shrinkWrap: true,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(children: [
                                      Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 16),
                                      SizedBox(width: 6),
                                      Text('Tips', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                                    ]),
                                    const SizedBox(height: 12),
                                    for (final tip in _kTips) ...[
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(tip, style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)))),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text('Ejemplos por categoría',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                              const SizedBox(height: 12),
                              for (final ex in _kExamples) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: c.surfaceTinted,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 32, height: 32,
                                            decoration: BoxDecoration(
                                              color: ex.color.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(ex.icon, size: 18, color: ex.color),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(ex.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(ex.text, style: TextStyle(fontSize: 13, color: c.muted, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => setState(() => _showGuide = false),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.violet,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Entendido', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Modal: Resultado
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
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 36, height: 4,
                          decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
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
                              Center(child: Text('Gasto reconocido',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink))),
                              const SizedBox(height: 4),
                              Center(child: Text('Revisa los datos y confirma para continuar',
                                  style: TextStyle(fontSize: 14, color: c.muted))),
                              const SizedBox(height: 20),
                              // Total
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Column(
                                  children: [
                                    const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_moneda(_extractedData!['currencyCode'] as String?)} ${((_extractedData!['total'] as num?) ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Detalles
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: c.surfaceTinted,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: c.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_extractedData!['descrip'] != null && (_extractedData!['descrip'] as String).isNotEmpty)
                                      _ResultField('Descripción', _extractedData!['descrip'] as String),
                                    if (_extractedData!['businessName'] != null)
                                      _ResultField('Razón Social', _extractedData!['businessName'] as String),
                                    if (_extractedData!['ruc'] != null)
                                      _ResultField('RUC', _extractedData!['ruc'] as String),
                                    _ResultField('Moneda', _extractedData!['currencyCode'] as String? ?? 'PEN'),
                                  ],
                                ),
                              ),
                              // Items
                              if ((_extractedData!['items'] as List?)?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: c.surfaceTinted,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Items (${(_extractedData!['items'] as List).length})',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink2)),
                                      const SizedBox(height: 12),
                                      for (final item in _extractedData!['items'] as List)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item['descrip'] as String? ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.ink)),
                                                    Text('${item['quantity']} × ${_moneda(_extractedData!['currencyCode'] as String?)} ${((item['unitPrice'] as num?) ?? 0).toStringAsFixed(2)}',
                                                        style: TextStyle(fontSize: 12, color: c.muted)),
                                                  ],
                                                ),
                                              ),
                                              Text('${_moneda(_extractedData!['currencyCode'] as String?)} ${((item['subtotal'] as num?) ?? 0).toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Acciones
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
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
                                    backgroundColor: AppTheme.violet,
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
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.ink)),
        ],
      ),
    );
  }
}
