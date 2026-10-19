import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/biometric_button.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../../../features/home/presentation/screens/main_shell_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isChecking = true;
  bool _needsBiometricUnlock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkAuthStatus();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      if (authProvider.isBiometricEnabled) {
        setState(() {
          _isChecking = false;
          _needsBiometricUnlock = true;
        });
        // Prompt unlock gate automatically (Mode A per PRD F02)
        _handleUnlockGate();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShellScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _handleUnlockGate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.unlockGate();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
      );
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: NeoColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SAFEEXAM',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  color: NeoColors.ink,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(color: NeoColors.ink),
            ],
          ),
        ),
      );
    }

    if (_needsBiometricUnlock) {
      final authProvider = Provider.of<AuthProvider>(context);
      final user = authProvider.currentUser;

      return Scaffold(
        backgroundColor: NeoColors.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SAFEEXAM',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 36,
                    color: NeoColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'INTEGRITY GATEWAY',
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: NeoColors.ink,
                  ),
                ),
                const SizedBox(height: 32),
                NeoCard(
                  header: const Text(
                    'GERBANG BIOMETRIK',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: NeoColors.ink,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: NeoColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: NeoColors.ink, width: 3),
                        ),
                        child: const Icon(Icons.security, size: 48, color: NeoColors.ink),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Halo, ${user?.name ?? 'Pengguna'}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Aplikasi diamankan dengan biometrik. Verifikasi identitas Anda untuk melanjutkan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 14,
                          color: NeoColors.ink,
                        ),
                      ),
                      const SizedBox(height: 24),
                      BiometricButton(
                        onPressed: _handleUnlockGate,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: NeoButton(
                          text: 'GANTI AKUN / KELUAR',
                          variant: NeoButtonVariant.secondary,
                          onPressed: _handleLogout,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
