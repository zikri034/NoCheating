import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../game/presentation/screens/pair_rush_screen.dart';
import '../../../exams/presentation/widgets/blockchain_receipt_dialog.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: const Text(
          'DASHBOARD',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: NeoColors.ink),
            onPressed: () {
              if (onNavigateTab != null) {
                onNavigateTab!(2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME BACK,',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: NeoColors.ink.withValues(alpha: 0.6),
                ),
              ),
              Text(
                user?.name ?? 'User',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: NeoColors.ink,
                ),
              ),
              const SizedBox(height: 32),

              // BIOMETRIC PROMO CARD (The "Ad" pop-up suggestion)
              if (!authProvider.isBiometricEnabled)
                _buildBiometricPromo(context),

              const SizedBox(height: 24),

              // MAIN MENU GRID
              const Text(
                'MAIN COMMANDS',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: NeoColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    title: 'START EXAM',
                    icon: Icons.edit_document,
                    color: NeoColors.primary,
                    onTap: () {
                      if (onNavigateTab != null) {
                        onNavigateTab!(1); // Go to Ujian
                      }
                    },
                  ),
                  _buildMenuCard(
                    title: 'PAIR RUSH',
                    icon: Icons.sports_esports,
                    color: NeoColors.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PairRushScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    title: 'FEEDBACK',
                    icon: Icons.chat_bubble_outline,
                    color: NeoColors.tertiary,
                    onTap: () {
                      if (onNavigateTab != null) {
                        onNavigateTab!(3); // Go to Saran
                      }
                    },
                  ),
                  _buildMenuCard(
                    title: 'INTEGRITAS',
                    icon: Icons.verified_user_outlined,
                    color: NeoColors.info,
                    onTap: () {
                      BlockchainReceiptDialog.show(
                        context,
                        attemptId: '00000000-0000-0000-0000-000000000000',
                        examTitle: 'Verifikasi Integritas Rantai',
                      );
                    },
                  ),
                  _buildMenuCard(
                    title: 'SETTING',
                    icon: Icons.settings,
                    color: NeoColors.surface,
                    onTap: () {
                      if (onNavigateTab != null) {
                        onNavigateTab!(2); // Go to Profile
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      }
                    },
                  ),
                  _buildMenuCard(
                    title: 'HISTORY',
                    icon: Icons.history,
                    color: NeoColors.surface,
                    onTap: () {
                      if (onNavigateTab != null) {
                        onNavigateTab!(1);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricPromo(BuildContext context) {
    return NeoCard(
      header: const Text(
        'SECURITY UPGRADE',
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
          const Text(
            'Lindungi integritas akun Anda dengan Autentikasi Biometrik. Lebih cepat, aman, dan tanpa kompromi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Hanken Grotesk',
              fontSize: 14,
              color: NeoColors.ink,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: NeoButton(
              text: 'AKTIFKAN BIOMETRIK',
              onPressed: () {
                if (onNavigateTab != null) {
                  onNavigateTab!(2);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NeoCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: NeoColors.ink, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: NeoColors.ink),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: NeoColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
