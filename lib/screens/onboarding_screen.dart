import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../services/notification_service.dart';
import '../widgets/auth_background.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  final List<OnboardingPageData> _pages = const [
    OnboardingPageData(
      title: 'Welcome to AapkeLawyer',
      subtitle: 'Find trusted advocates for any court, anytime, anywhere.',
      icon: Icons.balance,
    ),
    OnboardingPageData(
      title: 'Choose Your Role',
      subtitle: "Whether you're an advocate or someone seeking legal help.",
      icon: Icons.people_alt_outlined,
    ),
    OnboardingPageData(
      title: 'Services for All Courts',
      subtitle: 'Civil, Criminal, Family, Corporate - we cover it all.',
      icon: Icons.account_balance_outlined,
    ),
    OnboardingPageData(
      title: "Let's Get Started",
      subtitle: 'Sign up now and connect with legal professionals.',
      icon: Icons.handshake_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermissionAndSyncToken();
    });
  }

  Future<void> _openWelcome() async {
    await AppPreferences.completeOnboarding();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AuthBackground(
        child: PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (value) => setState(() => _page = value),
          itemBuilder: (context, index) => OnboardingPage(data: _pages[index]),
        ),
      ),
      bottomNavigationBar: Container(
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFF180B07).withValues(alpha: .88),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: .18)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Row(
          children: [
            TextButton(
              onPressed: _openWelcome,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? const Color(0xFFE8C8A7)
                        : Colors.white38,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                if (_page == _pages.length - 1) {
                  _openWelcome();
                  return;
                }
                _controller.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              },
              child: Text(
                _page == _pages.length - 1 ? 'Done' : 'Next',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: constraints.maxHeight < 600 ? 132 : 170,
                  height: constraints.maxHeight < 600 ? 132 : 170,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8C8A7).withValues(alpha: .93),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 24),
                    ],
                  ),
                  child: Icon(
                    data.icon,
                    size: constraints.maxHeight < 600 ? 68 : 88,
                    color: const Color(0xFF32251E),
                  ),
                ),
                SizedBox(height: constraints.maxHeight < 600 ? 28 : 48),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFEADFD8),
                    fontSize: 18,
                    height: 1.25,
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
