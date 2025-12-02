// lib/router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'firebase_providers.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/home/presentation/home_page.dart';
import 'features/devices/presentation/add_device_page.dart';

/// Pequeño helper para que GoRouter se refresque cuando cambia un Stream.
/// (equivalente al GoRouterRefreshStream de los ejemplos oficiales).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(firebaseAuthProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Se refresca cuando cambia el estado de autenticación
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),

    // Lógica de redirección según sesión
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loggingIn =
          state.uri.path == '/login' || state.uri.path == '/register';

      if (!loggedIn) {
        // No logueado: solo permitimos /login y /register
        return loggingIn ? null : '/login';
      }

      // Logueado: si intenta ir a /login o /register, lo mandamos a /home
      if (loggingIn) {
        return '/home';
      }

      return null; // sin redirección
    },

    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/devices/add',
        builder: (context, state) => const AddDevicePage(),
      ),
    ],
  );
});
