import 'package:flutter/material.dart';

import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_and_conditions_screen.dart';

class TermsCheck extends StatelessWidget {
  const TermsCheck({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'I agree to the ',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              _LegalLink(
                label: 'Terms & Conditions',
                page: const TermsAndConditionsScreen(),
              ),
              const Text(
                ' and ',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              _LegalLink(
                label: 'Privacy Policy',
                page: const PrivacyPolicyScreen(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.page});

  final String label;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE8C8A7),
          fontSize: 12,
          height: 1.3,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
