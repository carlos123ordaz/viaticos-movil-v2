# Viáticos Flutter

Replica del proyecto ViaticosAppMovil en Flutter con Material Design 3 y UX mejorada.

## Stack

- **Flutter** 3.x con Material 3
- **State Management**: Provider
- **HTTP**: Dio (con interceptor para refresh token automático)
- **Storage**: SharedPreferences
- **Navegación**: GoRouter
- **Imágenes**: ImagePicker + CachedNetworkImage
- **Animaciones**: Flutter nativo (sin paquetes externos)

## Cómo ejecutar

### 1. Instalar Flutter
Descarga Flutter SDK desde https://flutter.dev/docs/get-started/install

### 2. Inicializar el proyecto
```bash
cd viaticos_flutter
flutter create . --project-name viaticos_flutter --platforms=android,ios
flutter pub get
```

### 3. Ejecutar
```bash
flutter run
```

## Estructura del proyecto

```
lib/
├── core/
│   ├── constants/       # API endpoints
│   ├── theme/           # Material 3 theme
│   └── utils/           # Formatters, validators
├── data/
│   ├── models/          # UserModel, ExpenseModel, etc.
│   └── services/        # API service (Dio), Storage, Auth, Expenses
├── presentation/
│   ├── navigation/      # GoRouter + HomeScaffold con NavigationBar
│   ├── providers/       # AuthProvider, ExpenseProvider
│   ├── screens/
│   │   ├── auth/        # LoginScreen
│   │   ├── expenses/    # History, Add, Detail, Edit
│   │   └── profile/     # Profile, ChangePassword
│   └── widgets/         # ExpenseCard, AppLoader, EmptyState, ShimmerCard
├── app.dart             # MultiProvider + MaterialApp.router
└── main.dart            # Entry point
```

## Mejoras de UX sobre la versión React Native

| Feature | RN Original | Flutter |
|---------|-------------|---------|
| Splash screen | Básico | Animación con escala + fade |
| Login | Formulario plano | Tarjeta flotante con gradiente |
| Historial | Lista simple | Stats header expandible + search + filtros |
| Swipe to delete | Manual | Dismissible nativo con confirmación |
| Loading | Spinner | Shimmer skeleton cards |
| Empty state | Texto básico | Ilustración + CTA contextual |
| Categorías | Chips | Grid visual con iconos y colores |
| Navegación | Tabs inferior | Material 3 NavigationBar |
| Detalle gasto | Pantalla plana | Hero header con gradiente por categoría |
| Formulario | Scroll básico | Secciones con validación en tiempo real |

## Variables de entorno

Edita `lib/core/constants/api_constants.dart` para cambiar la URL base:

```dart
static const String baseUrl = 'https://viaticos-0sro.onrender.com/api';
```
