import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/auth_background.dart';
import 'client_dashboard.dart';
import 'lawyer_dashboard.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textProgress;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _logoScale = Tween<double>(begin: .68, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0, .68, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0, .42, curve: Curves.easeOut),
    );
    _textProgress = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(.28, 1, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _resolveNextScreen();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _resolveNextScreen() async {
    final minimumSplashTime = Future<void>.delayed(const Duration(seconds: 2));
    final onboardingComplete = await AppPreferences.isOnboardingComplete();

    Widget destination;
    if (!onboardingComplete && AuthService.currentUser == null) {
      destination = const OnboardingScreen();
    } else if (AuthService.currentUser != null) {
      try {
        final role = await AuthService.currentUserRole();
        await NotificationService.syncCurrentUserToken();
        destination = role == null
            ? const WelcomeScreen()
            : role.name == 'lawyer'
            ? const LawyerDashboard()
            : const ClientDashboard();
        if (role == null) await AuthService.signOut();
      } catch (_) {
        await AuthService.signOut();
        destination = const WelcomeScreen();
      }
    } else {
      destination = const WelcomeScreen();
    }

    await minimumSplashTime;
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        overlay: .66,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: constraints.maxHeight < 600 ? 150 : 190,
                              height: constraints.maxHeight < 600 ? 150 : 190,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .72),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFD5A66F,
                                    ).withValues(alpha: .28),
                                    blurRadius: 34,
                                    spreadRadius: 4,
                                  ),
                                  const BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 22,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo-new.jpeg',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Opacity(
                          opacity: _textProgress.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _textProgress.value)),
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFFF0D2B3),
                                  Colors.white,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'AAPKE LAWYER',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: constraints.maxWidth < 360
                                      ? 30
                                      : 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing:
                                      7 - (5.5 * _textProgress.value),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: _textProgress.value,
                          child: const Text(
                            'India’s legal partner, in your pocket',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFEADFD8),
                              fontSize: 15,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
