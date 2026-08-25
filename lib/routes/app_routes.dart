import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../models/user_role.dart';

/// Table de routage nommée de l'application.
class AppRoutes {
  AppRoutes._();

  static const onboarding = '/';
  static const roleSelection = '/role-selection';
  static const signup = '/signup';
  static const login = '/login';
  static const home = '/home';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());
      case signup:
        final role = settings.arguments as UserRole? ?? UserRole.client;
        return MaterialPageRoute(builder: (_) => SignupScreen(role: role));
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      default:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
    }
  }
}
