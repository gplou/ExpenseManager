import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/tasks/presentation/screen/tasks_list_screen.dart';
import '../../features/tasks/presentation/screen/task_detail_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/transactions/presentation/screens/transactions_list_screen.dart';

part 'router.g.dart';

// Rutas nombradas — evita hardcodear strings por toda la app
abstract class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/:id';
  static const transactions = '/transactions';
  static const addTransaction = '/transactions/add';
}

/// Notifier que escucha el stream de auth y notifica a GoRouter para
/// que re-evalúe el redirect sin necesidad de recrear el router completo.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  final authRepo = ref.read(authRepositoryProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: true,
    // Al cambiar el auth state, GoRouter re-evalúa redirect sin recrearse
    refreshListenable: _RouterRefreshNotifier(authRepo.authStateChanges),
    redirect: (context, state) {
      final isLoggedIn = authRepo.currentUser != null;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn && isAuthRoute) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.tasks,
        name: 'tasks',
        builder: (context, state) => const TasksListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'taskDetail',
            builder: (context, state) {
              final taskId = state.pathParameters['id']!;
              return TaskDetailScreen(taskId: taskId);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        name: 'addTransaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Página no encontrada: ${state.error}'),
      ),
    ),
  );
}
