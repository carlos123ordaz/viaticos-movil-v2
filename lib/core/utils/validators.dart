class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'El correo es requerido';
    final re = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!re.hasMatch(value)) return 'Correo inválido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es requerida';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? required(String? value, [String field = 'Este campo']) {
    if (value == null || value.trim().isEmpty) return '$field es requerido';
    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.isEmpty) return 'El monto es requerido';
    final n = double.tryParse(value.replaceAll(',', '.'));
    if (n == null) return 'Monto inválido';
    if (n <= 0) return 'El monto debe ser mayor a 0';
    return null;
  }
}
