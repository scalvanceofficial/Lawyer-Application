import 'package:flutter/material.dart';

import 'legal_policy_page.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPolicyPage(
      title: 'Terms & Conditions',
      introduction:
          'Please carefully read these terms and conditions ("Terms") before using our premium online platform dedicated to expediting the process of discovering and engaging with top-notch advocates across India. By accessing or using our platform, you agree to be bound by these Terms. If you do not agree, please do not use our platform.',
      sections: [
        LegalSection('1. Acceptance of Terms', [
          'By using AAPKE LAWYER, you agree to abide by these Terms and any additional terms that may apply to specific features or services offered on our platform. These Terms constitute a legally binding agreement between you and AAPKE LAWYER.',
        ]),
        LegalSection('2. Description of Service', [
          'AAPKE LAWYER is an online platform designed to help users discover and engage with advocates across India. We provide options intended to help users find legal professionals suited to their requirements.',
        ]),
        LegalSection('3. Registration and Account Security', [
          'To access certain features, you may be required to create an account. You agree to provide accurate and complete information and keep it current. You are responsible for maintaining the confidentiality of your credentials and for all activity under your account.',
        ]),
        LegalSection('4. Payment and Fees', [
          'Advocates are required to pay the applicable one-time registration fee. Users are charged the applicable platform or booking amount when engaging an advocate through the platform. Additional payment terms may apply and should be reviewed before completing a transaction.',
        ]),
        LegalSection('5. User Conduct', [
          'You agree to use AAPKE LAWYER only for lawful purposes and to comply with applicable laws and regulations.',
          '• Do not violate the rights of others, including intellectual property rights.',
          '• Do not transmit unlawful, harmful, threatening, abusive, harassing, defamatory, obscene, or otherwise objectionable material.',
          '• Do not interfere with or disrupt the operation of the platform or its servers.',
        ]),
        LegalSection('6. Intellectual Property', [
          'All content and materials available on AAPKE LAWYER, including text, graphics, logos, images, and software, are owned by AAPKE LAWYER or its licensors and are protected by applicable intellectual property laws. You may not reproduce, modify, distribute, or otherwise use them without prior written consent.',
        ]),
        LegalSection('7. Disclaimer of Warranties', [
          'AAPKE LAWYER makes no representations or warranties, express or implied, regarding the accuracy, reliability, or completeness of information or materials available on the platform. Your use of the platform is at your own risk.',
        ]),
        LegalSection('8. Limitation of Liability', [
          'To the extent permitted by law, AAPKE LAWYER will not be liable for indirect, incidental, special, consequential, or punitive damages arising from or connected with your use of the platform.',
        ]),
        LegalSection('9. Indemnification', [
          'You agree to indemnify, defend, and hold harmless AAPKE LAWYER and its officers, directors, employees, agents, and affiliates from claims, liabilities, damages, losses, costs, and expenses arising from your use of the platform or breach of these Terms.',
        ]),
        LegalSection('10. Governing Law', [
          'These Terms are governed by and construed in accordance with the laws of India, without regard to conflict-of-law principles.',
        ]),
        LegalSection('11. Changes to Terms', [
          'AAPKE LAWYER may modify these Terms at any time. Material changes may be communicated through the platform or by email. Continued use after a change constitutes acceptance of the revised Terms.',
        ]),
        LegalSection('12. Contact Us', [
          'Questions or concerns about these Terms may be sent to:',
          'Address: Pune, Maharashtra\nPhone: 90042 97172, 90040 87172\nEmail: aapkelawyer@gmail.com\nWorking hours: 24 hours',
          'By using AAPKE LAWYER, you acknowledge that you have read, understood, and agree to be bound by these Terms.',
        ]),
      ],
    );
  }
}
