import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/biometric_button.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'package:thereisnocheating/features/home/presentation/screens/main_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.initBiometricState();
    });
  }

  void _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi semua kolom login'),
          backgroundColor: NeoColors.danger,
        ),
      );
      return;
    }

    try {
      await authProvider.login(identifier, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login Berhasil!'),
          backgroundColor: NeoColors.success,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShellScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: NeoColors.danger,
        ),
      );
    }
  }

  void _handleBiometricLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.loginWithBiometrics();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login Biometrik Berhasil!'),
          backgroundColor: NeoColors.success,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShellScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: NeoColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: NeoColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: NeoColors.ink, width: 3),
                  boxShadow: const [
                    BoxShadow(color: NeoColors.ink, offset: Offset(4, 4), blurRadius: 0),
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/safeexamlogo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              NeoCard(
                header: const Text(
                  'SAFEEXAM LOGIN',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: NeoColors.ink,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Enter your credentials to access the integrity engine.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              NeoCard(
                child: Column(
                  children: [
                    NeoTextField(
                      controller: _identifierController,
                      label: 'NIM or Email',
                      hintText: 'Enter your NIM/Email...',
                    ),
                    const SizedBox(height: 20),
                    NeoTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: '********',
                      isPassword: true,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: NeoButton(
                        text: authProvider.isLoading ? 'LOADING...' : 'LOGIN DENGAN PASSWORD',
                        onPressed: authProvider.isLoading ? null : _handleLogin,
                      ),
                    ),
                    // Biometric Login Button (Mode B)
                    if (authProvider.isBiometricEnabled) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: NeoColors.ink, thickness: 1.5)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              'ATAU',
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: NeoColors.ink.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: NeoColors.ink, thickness: 1.5)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BiometricButton(
                        isLoading: authProvider.isLoading,
                        onPressed: _handleBiometricLogin,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  'Don\'t have an account? REGISTER',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    color: NeoColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
