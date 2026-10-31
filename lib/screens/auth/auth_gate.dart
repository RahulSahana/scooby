import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/battery_provider.dart';
import '../../providers/navigation_provider.dart';
import '../connect/connect_screen.dart';
import 'auth_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _AuthLoadingError();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoading();
        }
        if (snapshot.data == null) return const AuthScreen();

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BatteryProvider()),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ],
          child: const ConnectScreen(),
        );
      },
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AuthLoadingError extends StatelessWidget {
  const _AuthLoadingError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Firebase setup is incomplete. Finish the setup steps and reopen Scooby.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Run flutterfire configure from the Scooby project folder, then rebuild the app.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
