import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart' as ap;

/// Wraps a screen so it is only reachable when [ap.AuthProvider.isAuthenticated].
/// Used for named routes that sit outside [AuthGate]'s subtree.
class AuthRequired extends StatelessWidget {
  final Widget child;

  const AuthRequired({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();

    if (!auth.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    return child;
  }
}
