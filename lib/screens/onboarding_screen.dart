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

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  bool _isLoggingIn = false;
  String _loginEmail = '';
  String _loginPassword = '';
  int _currentPage = 0;

  // Password visibility
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _showLoginPassword = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (!_pageController.hasClients) return;
    HapticFeedback.lightImpact();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    if (!_pageController.hasClients) return;
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goToPage(int page) {
    if (!_pageController.hasClients) return;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.needsProfile && _currentPage != 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(3);
          setState(() => _currentPage = 3);
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isLoggingIn) {
          setState(() => _isLoggingIn = false);
        } else if (_currentPage > 0) {
          _prevPage();
        }
      },
      child: Scaffold(
        body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Branded header
                _buildBrandHeader(),
                const SizedBox(height: 32),

                // Error banner
                if (auth.errorMessage != null) ...[
                  _buildErrorBanner(auth),
                  const SizedBox(height: 16),
                ],

                // Progress dots — always reserve the same space to prevent Y-shift
                // during the login/register slide transition.
                Opacity(
                  opacity: _isLoggingIn ? 0.0 : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildProgressDots(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Main content area — AnimatedSwitcher between login and registration
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, animation) {
                      final isLogin = child.key == const ValueKey('login');
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: isLogin
                              ? const Offset(1.0, 0.0)
                              : const Offset(-1.0, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: _isLoggingIn
                        ? KeyedSubtree(
                            key: const ValueKey('login'),
                            child: SizedBox.expand(
                              child: _buildLoginView(auth),
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('register'),
                            child: SizedBox.expand(
                              child: PageView(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                onPageChanged: (page) =>
                                    setState(() => _currentPage = page),
                                children: [
                                  _buildWelcomePage(auth),
                                  _buildEmailPage(auth),
                                  _buildPasswordPage(auth),
                                  _buildProfilePage(auth),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/noterat-favicon-ios.webp',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Noterat',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.8,
            color: AppColors.styrianForest,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.styrianForest : AppColors.borderGray,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildErrorBanner(AuthProvider auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.kaiserRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: AppColors.kaiserRed.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.kaiserRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              auth.errorMessage!,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.kaiserRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => auth.clearError(),
            child: const Icon(
              Icons.close,
              color: AppColors.kaiserRed,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PAGE 1: WELCOME ─────────────────────────────────────────────────────────

  Widget _buildWelcomePage(AuthProvider auth) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/noterat-favicon-ios.webp',
            width: 88,
            height: 88,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Write together,\nanywhere.',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.8,
            color: AppColors.textDark,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Real-time collaborative notes. Create a shared workspace and write with your team instantly.',
          style: GoogleFonts.outfit(
            fontSize: 15,
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
            child: const Text('Create an Account'),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            auth.clearError();
            setState(() => _isLoggingIn = true);
          },
          child: Text(
            'Already have an account? Log in',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }

  // ─── PAGE 2: EMAIL ────────────────────────────────────────────────────────────

  Widget _buildEmailPage(AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your email',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll send a confirmation email to this address.",
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            initialValue: auth.email,
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              labelText: 'Email address',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email.';
              }
              if (!_isValidEmail(value)) return 'Enter a valid email address.';
              return null;
            },
            onChanged: (val) {
              auth.email = val.trim();
              if (auth.errorMessage != null) auth.clearError();
            },
          ),
          const SizedBox(height: 32),
          _buildNavRow(
            onBack: _prevPage,
            onForward: () {
              if (_emailFormKey.currentState!.validate()) {
                auth.clearError();
                _nextPage();
              }
            },
            forwardLabel: 'Next',
          ),
        ],
      ),
    );
  }

  // ─── PAGE 3: PASSWORD ─────────────────────────────────────────────────────────

  Widget _buildPasswordPage(AuthProvider auth) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set a password',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Minimum 6 characters.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textLight,
                  size: 20,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password.';
              }
              if (value.length < 6) return 'Must be at least 6 characters.';
              return null;
            },
            onChanged: (val) {
              auth.password = val;
              if (auth.errorMessage != null) auth.clearError();
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textLight,
                  size: 20,
                ),
                onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password.';
              }
              if (value != auth.password) return 'Passwords do not match.';
              return null;
            },
            onChanged: (val) {
              auth.confirmPassword = val;
              if (auth.errorMessage != null) auth.clearError();
            },
          ),
          const SizedBox(height: 32),
          auth.status == AuthStatus.authenticating
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.styrianForest,
                    ),
                  ),
                )
              : _buildNavRow(
                  onBack: _prevPage,
                  onForward: () async {
                    if (auth.status == AuthStatus.authenticating) return;
                    if (_passwordFormKey.currentState!.validate()) {
                      final success = await auth.registerUser();
                      if (success && mounted && _pageController.hasClients) {
                        _nextPage();
                      }
                    }
                  },
                  forwardLabel: 'Register',
                ),
        ],
      ),
    );
  }

  // ─── PAGE 4: PROFILE ──────────────────────────────────────────────────────────

  Widget _buildProfilePage(AuthProvider auth) {
    return Form(
      key: _profileFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your name?",
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This name is shown to collaborators in shared notes.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: auth.tempNickname,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'e.g. Alex',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name.';
              }
              return null;
            },
            onChanged: (val) {
              auth.tempNickname = val;
              if (auth.errorMessage != null) auth.clearError();
            },
          ),
          const SizedBox(height: 32),
          auth.status == AuthStatus.authenticating
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.styrianForest,
                    ),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (auth.status == AuthStatus.authenticating) return;
                      if (_profileFormKey.currentState!.validate()) {
                        HapticFeedback.lightImpact();
                        await auth.completeProfileSetup();
                      }
                    },
                    child: const Text('Get Started'),
                  ),
                ),
        ],
      ),
    );
  }

  // ─── LOGIN VIEW ───────────────────────────────────────────────────────────────

  Widget _buildLoginView(AuthProvider auth) {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to your Noterat account.',
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          TextFormField(
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'you@example.com',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email.';
              }
              return null;
            },
            onChanged: (val) {
              _loginEmail = val.trim();
              if (auth.errorMessage != null) auth.clearError();
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            obscureText: !_showLoginPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _showLoginPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textLight,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _showLoginPassword = !_showLoginPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password.';
              }
              return null;
            },
            onChanged: (val) {
              _loginPassword = val;
              if (auth.errorMessage != null) auth.clearError();
            },
          ),
          const SizedBox(height: 32),
          auth.status == AuthStatus.authenticating
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.styrianForest,
                    ),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (auth.status == AuthStatus.authenticating) return;
                          if (_loginFormKey.currentState!.validate()) {
                            HapticFeedback.lightImpact();
                            await auth.loginUser(_loginEmail, _loginPassword);
                          }
                        },
                        child: const Text('Log In'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        auth.clearError();
                        setState(() => _isLoggingIn = false);
                      },
                      child: Text(
                        'Back to sign up',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ─── SHARED NAV ROW ──────────────────────────────────────────────────────────

  Widget _buildNavRow({
    required VoidCallback onBack,
    required VoidCallback onForward,
    required String forwardLabel,
  }) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios, size: 14),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textLight,
            textStyle: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onForward,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
            label: Text(forwardLabel),
          ),
        ),
      ],
    );
  }
}
