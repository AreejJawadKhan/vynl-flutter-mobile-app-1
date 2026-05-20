import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/providers/auth_provider.dart' as ap;
import '../auth/auth_screen.dart';
import '../../shared/widgets/main_scaffold.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();

    if (!auth.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return auth.isAuthenticated
        ? const MainScaffold()
        : const AuthScreen();
  }
}