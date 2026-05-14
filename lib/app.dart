import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/services/api_service.dart';
import 'data/services/auth_service.dart';
import 'data/services/bitrix_task_service.dart';
import 'data/services/cost_center_service.dart';
import 'data/services/expense_report_service.dart';
import 'data/services/expense_service.dart';
import 'data/services/signature_service.dart';
import 'data/services/storage_service.dart';
import 'data/services/user_service.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/expense_provider.dart';

class ViaticosApp extends StatefulWidget {
  final StorageService storage;
  const ViaticosApp({super.key, required this.storage});

  @override
  State<ViaticosApp> createState() => _ViaticosAppState();
}

class _ViaticosAppState extends State<ViaticosApp> {
  late final ApiService _api;
  late final AuthService _authService;
  late final ExpenseService _expenseService;
  late final UserService _userService;
  late final CostCenterService _costCenterService;
  late final SignatureService _signatureService;
  late final BitrixTaskService _bitrixTaskService;
  late final ExpenseReportService _expenseReportService;
  late final AuthProvider _authProvider;
  late final ExpenseProvider _expenseProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.storage);
    _authService = AuthService(_api, widget.storage);
    _expenseService = ExpenseService(_api);
    _userService = UserService(_api);
    _costCenterService = CostCenterService(_api);
    _signatureService = SignatureService(_api);
    _bitrixTaskService = BitrixTaskService(_api);
    _expenseReportService = ExpenseReportService(_api, _bitrixTaskService);
    _authProvider = AuthProvider(_authService, _userService, widget.storage);
    _expenseProvider = ExpenseProvider(_expenseService);
    _router = buildRouter();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _expenseProvider),
        Provider.value(value: _authService),
        Provider.value(value: _expenseService),
        Provider.value(value: _costCenterService),
        Provider.value(value: _signatureService),
        Provider.value(value: _bitrixTaskService),
        Provider.value(value: _expenseReportService),
        Provider.value(value: widget.storage),
      ],
      child: MaterialApp.router(
        title: 'Viáticos',
        theme: AppTheme.light(),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'PE'),
      ),
    );
  }
}
