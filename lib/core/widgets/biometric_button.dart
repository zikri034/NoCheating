import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_service.dart';
import '../theme/neo_theme.dart';

class BiometricButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const BiometricButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<BiometricButton> createState() => _BiometricButtonState();
}

class _BiometricButtonState extends State<BiometricButton> {
  final BiometricService _biometricService = BiometricService();
  bool _isSupported = false;
  bool _isFaceId = false;
  bool _isLoadingBiometrics = true;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await _biometricService.canAuthenticate();
    if (!supported) {
      if (mounted) {
        setState(() {
          _isSupported = false;
          _isLoadingBiometrics = false;
        });
      }
      return;
    }

    final biometrics = await _biometricService.getAvailableBiometrics();
    final isFace = biometrics.contains(BiometricType.face);

    if (mounted) {
      setState(() {
        _isSupported = true;
        _isFaceId = isFace;
        _isLoadingBiometrics = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBiometrics || !_isSupported) {
      return const SizedBox.shrink();
    }

    final String buttonText = _isFaceId
        ? 'MASUK DENGAN FACE ID'
        : 'MASUK DENGAN SIDIK JARI';
    final IconData buttonIcon = _isFaceId ? Icons.face : Icons.fingerprint;

    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isLoading ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.isLoading ? null : () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isLoading
              ? NeoColors.muted
              : (_isPressed
                  ? NeoColors.tertiary.withValues(alpha: 0.8)
                  : NeoColors.tertiary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NeoColors.ink, width: 3),
          boxShadow: [
            BoxShadow(
              color: NeoColors.ink,
              offset: (_isPressed || widget.isLoading)
                  ? const Offset(2, 2)
                  : const Offset(6, 6),
              blurRadius: 0,
            ),
          ],
        ),
        transform: (_isPressed && !widget.isLoading)
            ? (Matrix4.translationValues(4, 4, 0))
            : Matrix4.identity(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(buttonIcon, color: NeoColors.ink, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                widget.isLoading ? 'MEMVERIFIKASI...' : buttonText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                  color: NeoColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
