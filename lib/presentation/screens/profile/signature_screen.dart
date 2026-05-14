import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/services/signature_service.dart';
import '../../providers/auth_provider.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  bool _saving = false;
  String? _lastUpdatedAt;
  final _picker = ImagePicker();

  Future<void> _selectSignature() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;

    final result = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 800,
      maxHeight: 400,
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final service = context.read<SignatureService>();
      await service.uploadSignature(userId, result.path);
      await auth.refreshUser();
      if (!mounted) return;
      setState(() => _lastUpdatedAt = DateTime.now().toIso8601String());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firma actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = 'No se pudo guardar la firma';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          msg = data['message']?.toString() ?? data['error']?.toString() ?? msg;
        } else if (data is String && data.isNotEmpty) {
          msg = data;
        } else if (e.message != null) {
          msg = e.message!;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().user;
    final signatureUrl = user?.signatureImageUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Firma')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.draw_outlined, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Firma digital',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      'Sube una imagen de tu firma para usarla en documentos.',
                      style: TextStyle(
                          fontSize: 13, color: colors.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          signatureUrl != null
              ? Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: CachedNetworkImage(
                    imageUrl: signatureUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: colors.outline, size: 48),
                    ),
                  ),
                )
              : Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: colors.outlineVariant,
                        style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 48, color: colors.outline),
                      const SizedBox(height: 12),
                      Text('No tienes una firma cargada',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        'Selecciona una imagen desde tu galería.',
                        style: TextStyle(
                            fontSize: 13, color: colors.outline),
                      ),
                    ],
                  ),
                ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _selectSignature,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(signatureUrl != null
                    ? Icons.refresh_rounded
                    : Icons.upload_rounded),
            label: Text(_saving
                ? 'Guardando...'
                : signatureUrl != null
                    ? 'Cambiar firma'
                    : 'Subir firma'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          if (_lastUpdatedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Última actualización: ${DateTime.parse(_lastUpdatedAt!).toLocal()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.outline),
            ),
          ],
        ],
      ),
    );
  }
}
