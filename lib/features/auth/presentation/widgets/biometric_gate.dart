import 'package:flutter/material.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/biometric_button.dart';
import '../../../../core/widgets/neo_card.dart';
import '../screens/login_screen.dart';

class BiometricGate extends StatefulWidget {
  final VoidCallback onPassed;

  const BiometricGate({
    super.key,
    required this.onPassed,
  });

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Auto prompt on gate opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptBiometric();
    });
  }

  Future<void> _promptBiometric() async {
    setState(() => _isAuthenticating = true);
    try {
      final success = await _biometricService.authenticate(
        localizedReason: 'Konfirmasi identitas Anda untuk melanjutkan',
      );
      if (success) {
        widget.onPassed();
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeoCard(
                header: const Text(
                  'GERBANG BIOMETRIK',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: NeoColors.ink,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: NeoColors.tertiary,
                        shape: BoxShape.circle,
                        border: Border.all(color: NeoColors.ink, width: 3),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'VERIFIKASI INTEGRITAS',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sesi Anda dilindungi. Verifikasi biometrik diperlukan sebelum mengakses sistem SafeExam.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 14,
                        color: NeoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 24),
                    BiometricButton(
                      isLoading: _isAuthenticating,
                      onPressed: _promptBiometric,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Pakai Password / Login Ulang',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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