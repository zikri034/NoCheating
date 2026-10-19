import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thereisnocheating/core/theme/neo_theme.dart';
import 'package:thereisnocheating/core/network/dio_client.dart';
import 'package:thereisnocheating/features/auth/data/repositories/auth_repository.dart';
import 'package:thereisnocheating/features/auth/presentation/providers/auth_provider.dart';
import 'package:thereisnocheating/features/auth/presentation/screens/auth_gate_screen.dart';
import 'package:thereisnocheating/features/exams/data/repositories/exam_repository.dart';
import 'package:thereisnocheating/features/exams/presentation/providers/exam_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SafeExamApp extends StatelessWidget {
  const SafeExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) =>
              AuthRepository(DioClient.create(), const FlutterSecureStorage()),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthProvider(context.read<AuthRepository>()),
        ),
        Provider<ExamRepository>(
          create: (_) => ExamRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) => ExamProvider(repository: context.read<ExamRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'SafeExam',
        debugShowCheckedModeBanner: false,
        theme: NeoTheme.lightTheme,
        home: const AuthGateScreen(),
      ),
    );
  }
}
