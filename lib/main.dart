// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'services/supabase_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isSupabaseConfigured = false;
  try {
    // Check if the user has replaced placeholder credentials
    if (SupabaseService.supabaseUrl != 'https://your-supabase-project.supabase.co' &&
        SupabaseService.supabaseAnonKey != 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your-anon-key') {
      await Supabase.initialize(
        url: SupabaseService.supabaseUrl,
        anonKey: SupabaseService.supabaseAnonKey,
      );
      isSupabaseConfigured = true;
    }
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MyApp(isSupabaseConfigured: isSupabaseConfigured),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isSupabaseConfigured;

  const MyApp({super.key, required this.isSupabaseConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOTERAT',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: isSupabaseConfigured 
          ? const AuthGateway() 
          : const SupabaseConfigurationErrorPage(),
    );
  }
}

class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.uninitialized:
        return const Scaffold(
          backgroundColor: AppColors.glacialWhite,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.styrianForest),
          ),
        );
      case AuthStatus.authenticated:
        return const DashboardScreen();
      case AuthStatus.authenticating:
      case AuthStatus.needsProfile:
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const OnboardingScreen();
    }
  }
}

class SupabaseConfigurationErrorPage extends StatelessWidget {
  const SupabaseConfigurationErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glacialWhite,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 80,
                  color: AppColors.kaiserRed,
                ),
                const SizedBox(height: 24),
                Text(
                  'Configuration Required',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please update your Supabase URL and Anon Key in the source code to start using the app.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: AppColors.textLight,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.steelLight,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: AppColors.borderGray, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step 1: Open the configuration file:',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'lib/services/supabase_service.dart',
                        style: GoogleFonts.jetBrainsMono(color: AppColors.styrianForest, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Step 2: Replace placeholder credentials:',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'supabaseUrl = \'...\'\nsupabaseAnonKey = \'...\'',
                        style: GoogleFonts.jetBrainsMono(color: AppColors.textLight, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
