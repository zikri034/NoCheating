import 'package:flutter/material.dart';
import '../../../../core/theme/neo_theme.dart';
import '../../../../core/widgets/neo_button.dart';
import '../../../../core/widgets/neo_card.dart';
import '../../../../core/widgets/neo_text_field.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'student';
  final List<String> _roles = ['student', 'lecturer'];

  void _handleRegister() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final nim = _nimController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // Client-side validation to match server Zod rules
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters long')),
      );
      return;
    }

    if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must contain at least one letter')),
      );
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must contain at least one number')),
      );
      return;
    }

    try {
      await authProvider.register(
        name: name,
        email: email,
        password: password,
        role: _selectedRole,
        nim: nim,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration Successful!')),
      );
      // Navigate back to login or home
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nimController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: NeoColors.primary,
        elevation: 0,
        title: const Text(
          'JOIN THE SYSTEM',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w800,
            color: NeoColors.ink,
          ),
        ),
        shape: const Border(
          bottom: BorderSide(color: NeoColors.ink, width: 3),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              NeoCard(
                header: const Text(
                  'CREATE ACCOUNT',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: NeoColors.ink,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    NeoTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hintText: 'Enter your full name...',
                    ),
                    const SizedBox(height: 20),
                    NeoTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hintText: 'email@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    NeoTextField(
                      controller: _nimController,
                      label: 'NIM (Optional)',
                      hintText: 'Student ID number...',
                    ),
                    const SizedBox(height: 20),
                    // Role Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'USER ROLE',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: NeoColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _roles.map((role) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _selectedRole == role,
                                      onChanged: (val) {
                                        setState(() => _selectedRole = role);
                                      },
                                      activeColor: NeoColors.ink,
                                      checkColor: NeoColors.primary,
                                      side: const BorderSide(color: NeoColors.ink, width: 2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    role.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'Space Mono',
                                      fontWeight: FontWeight.w700,
                                      color: NeoColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    NeoTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: '********',
                      isPassword: true,
                    ),
                    const SizedBox(height: 20),
                    NeoTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      hintText: '********',
                      isPassword: true,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: NeoButton(
                        text: authProvider.isLoading ? 'Registering...' : 'CREATE ACCOUNT',
                        onPressed: authProvider.isLoading ? null : _handleRegister,
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
}
