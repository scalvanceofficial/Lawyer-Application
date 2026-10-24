import 'package:flutter/material.dart';

import '../models/user_role.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_and_conditions_screen.dart';
import 'login_screen.dart';
import '../widgets/auth_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openLogin(BuildContext context, UserRole role) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LoginScreen(role: role)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: constraints.maxHeight < 720 ? 142 : 174,
                          height: constraints.maxHeight < 720 ? 142 : 174,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFFE8C8A7,
                            ).withValues(alpha: .94),
                            border: Border.all(color: Colors.white54, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 22,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo-new.jpeg',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                        SizedBox(height: constraints.maxHeight < 720 ? 20 : 32),
                        const Text(
                          'WELCOME TO AAPKE LAWYER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Discover and connect with top advocates in your area with ease!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFEADFD8),
                            fontSize: 20,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Login as ?',
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.person_outline),
                                label: const Text('USER'),
                                onPressed: () =>
                                    _openLogin(context, UserRole.client),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.gavel),
                                label: const Text('ADVOCATE'),
                                onPressed: () =>
                                    _openLogin(context, UserRole.lawyer),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const TermsAndConditionsScreen(),
                              ),
                            ),
                            child: const Text('Terms & Conditions'),
                          ),
                          const Text(
                            '|',
                            style: TextStyle(color: Colors.white38),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            ),
                            child: const Text('Privacy Policy'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
