// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  bool _isLoggingIn = false;
  String _loginEmail = '';
  String _loginPassword = '';
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (!_pageController.hasClients) return;
    HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    if (!_pageController.hasClients) return;
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPage(int page) {
    if (!_pageController.hasClients) return;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Redirect logic: if profile setup is needed (after successful registration)
    // we force the page view to Page 3 (0-indexed Page 4)
    if (auth.status == AuthStatus.needsProfile &&
        _currentPage != 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(3);
          setState(() {
            _currentPage = 3;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.glacialWhite,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Top header logo representation
                const SizedBox(height: 20),
                Text(
                  'NOTERAT',
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.5,
                    color: AppColors.styrianForest,
                  ),
                ),
                const SizedBox(height: 40),

                // Error alert pill if present
                if (auth.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.kaiserRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: AppColors.kaiserRed,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.kaiserRed,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppColors.kaiserRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.kaiserRed,
                            size: 16,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => auth.clearError(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Expanded(
                  child: _isLoggingIn
                      ? _buildLoginView(auth)
                      : PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (page) {
                            setState(() {
                              _currentPage = page;
                            });
                          },
                          children: [
                            _buildGreetingPage(auth),
                            _buildEmailPage(auth),
                            _buildPasswordPage(auth),
                            _buildProfilePage(auth),
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

  // --- PAGE 1: HELLO (THE GREETING) ---
  Widget _buildGreetingPage(AuthProvider auth) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.landscape_outlined,
          size: 72,
          color: AppColors.styrianForest,
        ),
        const SizedBox(height: 30),
        Text(
          'Welcome to the Summit',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'A precise, high-performance workspace engineered for real-time offline-first text collaboration.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: AppColors.textLight,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _goToPage(1),
            child: const Text('Get Started'),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              auth.clearError();
              setState(() {
                _isLoggingIn = true;
              });
            },
            child: const Text('Log In'),
          ),
        ),
      ],
    );
  }

  // --- PAGE 2: EMAIL ENTRY ---
  Widget _buildEmailPage(AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your Email',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'We will use this to identify you on the network.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            initialValue: auth.email,
            decoration: const InputDecoration(
              hintText: 'email@example.com',
              labelText: 'Email Address',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email address.';
              }
              if (!_isValidEmail(value)) {
                return 'Please enter a valid email format.';
              }
              return null;
            },
            onChanged: (val) => auth.email = val.trim(),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _prevPage,
                    child: const Text('Back'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_emailFormKey.currentState!.validate()) {
                        auth.clearError();
                        _nextPage();
                      }
                    },
                    child: const Text('Next'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PAGE 3: PASSWORD SETUP ---
  Widget _buildPasswordPage(AuthProvider auth) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your Password',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Must be at least 6 characters.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: '••••••',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
            onChanged: (val) => auth.password = val,
          ),
          const SizedBox(height: 16),
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              hintText: '••••••',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password.';
              }
              return null;
            },
            onChanged: (val) => auth.confirmPassword = val,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _prevPage,
                    child: const Text('Back'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: auth.status == AuthStatus.authenticating
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.styrianForest,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () async {
                            if (auth.status == AuthStatus.authenticating) return;
                            if (_passwordFormKey.currentState!.validate()) {
                              final success = await auth.registerUser();
                              if (success && mounted && _pageController.hasClients) {
                                // Transition to profile naming screen
                                _nextPage();
                              }
                            }
                          },
                          child: const Text('Register'),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PAGE 4: WELCOME & PROFILE CREATION ---
  Widget _buildProfilePage(AuthProvider auth) {
    return Form(
      key: _profileFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should we call you?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your nickname will represent your cursor edits and invite profiles.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: auth.tempNickname,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              hintText: 'e.g. Alpinist',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a nickname.';
              }
              return null;
            },
            onChanged: (val) => auth.tempNickname = val,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: auth.status == AuthStatus.authenticating
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.styrianForest,
                    ),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      if (auth.status == AuthStatus.authenticating) return;
                      if (_profileFormKey.currentState!.validate()) {
                        final success = await auth.completeProfileSetup();
                        if (success) {
                          HapticFeedback.lightImpact();
                          // AuthProvider state change handles redirecting to Dashboard
                        }
                      }
                    },
                    child: const Text('Complete Setup'),
                  ),
          ),
        ],
      ),
    );
  }

  // --- LOG IN VIEW (TOGGLEABLE) ---
  Widget _buildLoginView(AuthProvider auth) {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to access your synchronized documents.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'email@example.com',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email.';
              }
              return null;
            },
            onChanged: (val) => _loginEmail = val.trim(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: '••••••',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password.';
              }
              return null;
            },
            onChanged: (val) => _loginPassword = val,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      auth.clearError();
                      setState(() {
                        _isLoggingIn = false;
                      });
                    },
                    child: const Text('Back'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: auth.status == AuthStatus.authenticating
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.styrianForest,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () async {
                            if (auth.status == AuthStatus.authenticating) return;
                            if (_loginFormKey.currentState!.validate()) {
                              final success = await auth.loginUser(
                                _loginEmail,
                                _loginPassword,
                              );
                              if (success) {
                                HapticFeedback.lightImpact();
                                // Auth state change redirects to Dashboard
                              }
                            }
                          },
                          child: const Text('Log In'),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
