import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/expenses/add_expense_screen.dart';
import '../screens/expenses/capture_screen.dart';
import '../screens/expenses/edit_expense_screen.dart';
import '../screens/expenses/expense_detail_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/expenses/history_screen.dart';
import '../screens/expenses/voice_expense_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/signature_screen.dart';
import '../screens/splash_screen.dart';
import 'home_scaffold.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final isAuth = auth.isAuthenticated;
      final loc = state.uri.toString();

      if (loc == '/splash') return null;
      if (!isAuth && loc != '/login') return '/login';
      if (isAuth && loc == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HistoryScreen()),
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddExpenseScreen(
            prefillData: extra?['prefillData'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: '/voice-expense',
        builder: (_, __) => const VoiceExpenseScreen(),
      ),
      GoRoute(
        path: '/capture',
        builder: (_, __) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/expense/:id',
        builder: (_, state) => ExpenseDetailScreen(expenseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/edit-expense/:id',
        builder: (_, state) => EditExpenseScreen(expenseId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/signature', builder: (_, __) => const SignatureScreen()),
    ],
  );
}
