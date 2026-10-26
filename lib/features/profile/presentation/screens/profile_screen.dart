import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_dialog.dart';
import '../../../../core/widgets/neo_text_field.dart';
import '../../../../core/widgets/neo_snackbar.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/presentation/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;

  const ProfileScreen({super.key, this.isTab = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BiometricService _biometricService = BiometricService();
  final ImagePicker _picker = ImagePicker();

  bool _deviceSupportsBiometrics = false;
  String _biometricTypeLabel = 'Biometrik';
  bool _isCheckingSupport = true;
  bool _notificationsEnabled = true;

  List<Map<String, dynamic>> _devices = [];
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _checkHardware();
    _loadDevices();
  }

  Future<void> _checkHardware() async {
    final supported = await _biometricService.canAuthenticate();
    final label = await _biometricService.getBiometricLabel();
    if (mounted) {
      setState(() {
        _deviceSupportsBiometrics = supported;
        _biometricTypeLabel = label;
        _isCheckingSupport = false;
      });
    }
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final devices = await authProvider.getBiometricDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDevices = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      final file = File(image.path);
      final fileSize = await file.length();
      if (fileSize > 2 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ukuran foto maksimal 2 MB sesuai ketentuan PRD'),
            backgroundColor: NeoColors.danger,
          ),
        );
        return;
      }

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.uploadAvatar(image.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui!'),
          backgroundColor: NeoColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunggah foto: $e'),
          backgroundColor: NeoColors.danger,
        ),
      );
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: NeoColors.ink, width: 3),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'PILIH SUMBER FOTO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: NeoColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: NeoColors.ink),
              title: const Text(
                'Kamera',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  color: NeoColors.ink,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
            const Divider(color: NeoColors.ink, thickness: 1.5),
            ListTile(
              leading: const Icon(Icons.photo_library, color: NeoColors.ink),
              title: const Text(
                'Galeri',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  color: NeoColors.ink,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final controller = TextEditingController(text: authProvider.currentUser?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => NeoDialog(
        title: 'UBAH NAMA',
        content: NeoTextField(
          label: 'Nama Lengkap',
          hintText: 'Masukkan nama lengkap baru',
          controller: controller,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'BATAL',
                  backgroundColor: NeoColors.surface,
                  textColor: NeoColors.ink,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  text: 'SIMPAN',
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama minimal 2 karakter'),
                          backgroundColor: NeoColors.danger,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await authProvider.updateProfile(newName);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nama profil berhasil diperbarui!'),
                          backgroundColor: NeoColors.success,
                        ),
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
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => NeoDialog(
        title: 'GANTI PASSWORD',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeoTextField(
              label: 'Password Lama',
              hintText: 'Masukkan password saat ini',
              isPassword: true,
              controller: oldPasswordController,
            ),
            const SizedBox(height: 12),
            NeoTextField(
              label: 'Password Baru',
              hintText: 'Min. 8 karakter (huruf & angka)',
              isPassword: true,
              controller: newPasswordController,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: NeoButton(
                  text: 'BATAL',
                  backgroundColor: NeoColors.surface,
                  textColor: NeoColors.ink,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoButton(
                  text: 'GANTI',
                  backgroundColor: NeoColors.danger,
                  textColor: Colors.white,
                  onPressed: () async {
                    final oldPass = oldPasswordController.text;
                    final newPass = newPasswordController.text;

                    if (oldPass.isEmpty || newPass.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password baru minimal 8 karakter'),
                          backgroundColor: NeoColors.danger,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    try {
                      await authProvider.changePassword(
                        oldPassword: oldPass,
                        newPassword: newPass,
                      );
                      await _loadDevices();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password berhasil diubah. Perangkat biometrik telah dicabut demi keamanan.'),
                          backgroundColor: NeoColors.success,
                        ),
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
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onBiometricToggle(bool value) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (value) {
      try {
        await authProvider.enrollBiometrics();
        await _loadDevices();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login $_biometricTypeLabel berhasil diaktifkan!'),
            backgroundColor: NeoColors.success,
          ),
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
    } else {
      try {
        await authProvider.disableBiometrics();
        await _loadDevices();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login $_biometricTypeLabel dinonaktifkan'),
            backgroundColor: NeoColors.ink,
          ),
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
  }

  void _confirmRevokeDevice(String deviceId, String? deviceName) async {
    final confirmed = await NeoDialog.showConfirmation(
      context: context,
      title: 'CABUT PERANGKAT',
      message: 'Apakah Anda yakin ingin mencabut akses biometrik untuk "${deviceName ?? 'Perangkat'}"?',
      confirmLabel: 'CABUT',
      isDangerous: true,
    );

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      try {
        await authProvider.revokeBiometricDevice(deviceId);
        await _loadDevices();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perangkat biometrik berhasil dicabut'),
            backgroundColor: NeoColors.success,
          ),
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
  }

  void _handleLogout() async {
    final confirmed = await NeoDialog.showConfirmation(
      context: context,
      title: 'KONFIRMASI LOGOUT',
      message: 'Apakah Anda yakin ingin keluar dari SafeExam?',
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

  String _formatJoinedDate(DateTime? dt) {
    if (dt == null) return '2026';
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt.toLocal());
    } catch (_) {
      try {
        return DateFormat('dd MMMM yyyy').format(dt.toLocal());
      } catch (_) {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    final String joinedDate = _formatJoinedDate(user?.createdAt);

    return Scaffold(
      backgroundColor: NeoColors.bg,
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        automaticallyImplyLeading: !widget.isTab,
        title: const Text(
          'PROFIL PENGGUNA',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: NeoColors.ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // INFORMASI AKUN CARD
            NeoCard(
              header: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'INFORMASI AKUN',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: NeoColors.ink,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: NeoColors.ink),
                    onPressed: _showEditNameDialog,
                    tooltip: 'Ubah Nama',
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Avatar with hard shadow
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: NeoColors.primary,
                          border: Border.all(color: NeoColors.ink, width: 3),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: NeoColors.ink,
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: user?.avatarPath != null && user!.avatarPath!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: DioClient.resolveUrl(user.avatarPath!),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: NeoColors.ink),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.person, size: 60, color: NeoColors.ink),
                              )
                            : const Icon(Icons.person, size: 60, color: NeoColors.ink),
                      ),
                      GestureDetector(
                        onTap: _showAvatarOptions,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: NeoColors.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: NeoColors.ink, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: NeoColors.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Pengguna SafeExam',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: NeoColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'email@safeexam.ac.id',
                    style: const TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 14,
                      color: NeoColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Badges: Role & NIM
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: user?.role == 'lecturer' ? NeoColors.info : NeoColors.primary,
                          border: Border.all(color: NeoColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user?.role == 'lecturer' ? 'DOSEN' : 'MAHASISWA',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                      ),
                      if (user?.nim != null && user!.nim!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: NeoColors.surface,
                            border: Border.all(color: NeoColors.ink, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NIM: ${user.nim}',
                            style: const TextStyle(
                              fontFamily: 'Space Mono',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: NeoColors.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bergabung sejak: $joinedDate',
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 12,
                      color: NeoColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // PENGATURAN KEAMANAN CARD
            NeoCard(
              header: const Text(
                'PENGATURAN KEAMANAN',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: NeoColors.ink,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    activeTrackColor: NeoColors.primary,
                    activeThumbColor: NeoColors.ink,
                    title: Text(
                      'Login $_biometricTypeLabel',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w700,
                        color: NeoColors.ink,
                      ),
                    ),
                    subtitle: Text(
                      _isCheckingSupport
                          ? 'Memeriksa sensor perangkat...'
                          : (!_deviceSupportsBiometrics
                              ? 'Sensor biometrik tidak tersedia atau belum didaftarkan di sistem'
                              : 'Gunakan $_biometricTypeLabel untuk masuk dan verifikasi ujian'),
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 13,
                        color: _deviceSupportsBiometrics ? NeoColors.ink : NeoColors.danger,
                      ),
                    ),
                    value: authProvider.isBiometricEnabled,
                    onChanged: (_deviceSupportsBiometrics && !authProvider.isLoading)
                        ? _onBiometricToggle
                        : null,
                  ),
                  const Divider(color: NeoColors.ink, thickness: 1.5),
                  SwitchListTile(
                    activeTrackColor: NeoColors.primary,
                    activeThumbColor: NeoColors.ink,
                    title: const Text(
                      'Notifikasi Pengingat Ujian',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w700,
                        color: NeoColors.ink,
                      ),
                    ),
                    subtitle: const Text(
                      'Ingatkan jadwal ujian dan publikasi hasil (F15)',
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 13,
                        color: NeoColors.ink,
                      ),
                    ),
                    value: _notificationsEnabled,
                    onChanged: (val) async {
                      setState(() => _notificationsEnabled = val);
                      if (val) {
                        await NotificationService.instance.requestNotificationPermission();
                        await NotificationService.instance.requestExactAlarmsPermission();
                      } else {
                        await NotificationService.instance.cancelAllReminders();
                      }
                    },
                  ),
                  if (_notificationsEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: NeoColors.surface,
                                side: const BorderSide(color: NeoColors.ink, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.notifications_active_outlined, size: 16, color: NeoColors.ink),
                              label: const Text(
                                'UJI NOTIFIKASI',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                              onPressed: () async {
                                final notifAllowed = await NotificationService.instance.areNotificationsEnabled();
                                if (!notifAllowed) {
                                  await NotificationService.instance.requestNotificationPermission();
                                }
                                await NotificationService.instance.showTestNotification();
                                if (context.mounted) {
                                  NeoSnackbar.showSuccess(
                                    context,
                                    title: 'NOTIFIKASI TERKIRIM',
                                    message: 'Periksa status bar atau notifikasi perangkat untuk melihat notifikasi uji.',
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: NeoColors.tertiary,
                                side: const BorderSide(color: NeoColors.ink, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.alarm_on_outlined, size: 16, color: NeoColors.ink),
                              label: const Text(
                                'UJI ALARM (5 DETIK)',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: NeoColors.ink,
                                ),
                              ),
                              onPressed: () async {
                                final notifAllowed = await NotificationService.instance.areNotificationsEnabled();
                                if (!notifAllowed) {
                                  final granted = await NotificationService.instance.requestNotificationPermission();
                                  if (!granted && context.mounted) {
                                    NeoSnackbar.showWarning(
                                      context,
                                      title: 'IZIN NOTIFIKASI DIBUTUHKAN',
                                      message: 'Aktifkan izin notifikasi di pengaturan HP untuk menampilkan alarm SafeExam.',
                                    );
                                    return;
                                  }
                                }

                                final canExact = await NotificationService.instance.canScheduleExactNotifications();
                                if (!canExact) {
                                  if (context.mounted) {
                                    NeoSnackbar.showWarning(
                                      context,
                                      title: 'IZIN ALARM TEPAT DIBUTUHKAN',
                                      message: 'Izinkan "Alarm & Pengingat" pada pengaturan HP agar alarm berdering tepat waktu.',
                                    );
                                  }
                                  await NotificationService.instance.requestExactAlarmsPermission();
                                  return;
                                }

                                final success = await NotificationService.instance.scheduleQuickTestNotification(delaySeconds: 5);
                                if (context.mounted) {
                                  if (success) {
                                    NeoSnackbar.showInfo(
                                      context,
                                      title: 'PENGINGAT DIJADWALKAN',
                                      message: 'Alarm notifikasi akan berdering dalam 5 detik.',
                                    );
                                  } else {
                                    NeoSnackbar.showError(
                                      context,
                                      title: 'GAGAL MENJADWALKAN',
                                      message: 'Periksa izin alarm tepat (Exact Alarm) pada pengaturan perangkat Anda.',
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(color: NeoColors.ink, thickness: 1.5),
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: NeoColors.ink),
                    title: const Text(
                      'Ganti Password',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w700,
                        color: NeoColors.ink,
                      ),
                    ),
                    subtitle: const Text(
                      'Mengubah password akan mencabut seluruh sesi & biometrik',
                      style: TextStyle(
                        fontFamily: 'Hanken Grotesk',
                        fontSize: 12,
                        color: NeoColors.ink,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: NeoColors.ink),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DAFTAR PERANGKAT BIOMETRIK (F13)
            NeoCard(
              header: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PERANGKAT TERIKAT',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: NeoColors.ink,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: NeoColors.ink),
                    onPressed: _loadDevices,
                    tooltip: 'Muat ulang',
                  ),
                ],
              ),
              child: _isLoadingDevices
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator(color: NeoColors.ink)),
                    )
                  : _devices.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Belum ada perangkat biometrik yang didaftarkan.',
                            style: TextStyle(
                              fontFamily: 'Hanken Grotesk',
                              fontSize: 14,
                              color: NeoColors.ink,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _devices.length,
                          separatorBuilder: (context, index) => const Divider(color: NeoColors.ink, thickness: 1),
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isRevoked = device['revoked_at'] != null;
                            final platform = device['platform'] ?? 'android';
                            final name = device['device_name'] ?? 'Perangkat ${platform.toUpperCase()}';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isRevoked ? NeoColors.muted : NeoColors.primary,
                                  border: Border.all(color: NeoColors.ink, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  platform == 'ios' ? Icons.apple : Icons.phone_android,
                                  color: NeoColors.ink,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  decoration: isRevoked ? TextDecoration.lineThrough : null,
                                  color: isRevoked ? NeoColors.ink.withValues(alpha: 0.5) : NeoColors.ink,
                                ),
                              ),
                              subtitle: Text(
                                isRevoked ? 'Dicabut' : 'Aktif',
                                style: TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isRevoked ? NeoColors.danger : NeoColors.success,
                                ),
                              ),
                              trailing: !isRevoked
                                  ? OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: NeoColors.danger,
                                        side: const BorderSide(color: NeoColors.danger, width: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () => _confirmRevokeDevice(
                                        device['device_id'],
                                        name,
                                      ),
                                      child: const Text(
                                        'CABUT',
                                        style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
            ),
            const SizedBox(height: 24),

            // LOGOUT BUTTON
            NeoButton(
              text: 'KELUAR DARI AKUN',
              variant: NeoButtonVariant.danger,
              onPressed: _handleLogout,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
