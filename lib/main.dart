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
      title: 'Noterat',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
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
      case AuthStatus.authenticating:
        // FIX: never show login screen while authentication is in progress.
        // Previously, 'authenticating' routed to OnboardingScreen, causing
        // a 1-3s flash of the login page on every cold start for returning users.
        return const _SplashScreen();

      case AuthStatus.authenticated:
        return const DashboardScreen();

      case AuthStatus.needsProfile:
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const OnboardingScreen();
    }
  }
}

/// Shown while the app resolves auth state. Replaces the raw CircularProgressIndicator
/// centered on a blank screen with a branded loading experience.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.glacialWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/noterat-favicon-ios.webp',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Noterat',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.0,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.styrianForest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupabaseConfigurationErrorPage extends StatelessWidget {
  const SupabaseConfigurationErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  'Setup Required',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Update your Supabase credentials in the source code to start using Noterat.',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
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
                        'Open this file:',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'lib/services/supabase_service.dart',
                        style: GoogleFonts.jetBrainsMono(color: AppColors.styrianForest, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Replace the placeholder URL and key with your project credentials.',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textLight),
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
