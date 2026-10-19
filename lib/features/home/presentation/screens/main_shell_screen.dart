import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_bottom_nav.dart';
import '../../../../core/widgets/neo_dialog.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';
import '../../../../features/exams/presentation/screens/exams_screen.dart';
import '../../../../features/feedback/presentation/screens/feedback_screen.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import 'home_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await NeoDialog.showConfirmation(
      context: context,
      title: 'KONFIRMASI LOGOUT',
      message: 'Apakah Anda yakin ingin keluar dari akun SafeExam?',
      confirmLabel: 'KELUAR',
      isDangerous: true,
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreen(onNavigateTab: _onTabSelected),
      const ExamsScreen(),
      const ProfileScreen(isTab: true),
      const FeedbackScreen(),
    ];

    return Scaffold(
      backgroundColor: NeoColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NeoBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        onLogoutTap: _handleLogout,
      ),
    );
  }
}
