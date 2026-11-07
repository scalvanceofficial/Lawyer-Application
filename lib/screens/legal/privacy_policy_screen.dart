import 'package:flutter/material.dart';

import 'legal_policy_page.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPolicyPage(
      title: 'Privacy Policy',
      introduction:
          'At AAPKE LAWYER, we are committed to protecting your privacy and the security of your personal information. This policy explains how we collect, use, disclose, and protect information provided while using our platform.',
      sections: [
        LegalSection('1. Information We Collect', [
          'We may collect information provided by advocates during registration, including name, email address, contact number, experience, Bar Council ID, areas of expertise, and courts of practice.',
          'We may collect information provided by users during registration, including name, email address, contact number, date of birth, and sex.',
          'We may collect case details and preferences submitted by users when requesting legal services, along with information collected automatically through cookies and similar technologies.',
        ]),
        LegalSection('2. Use of Information', [
          'We use information to provide and improve our services, match users with suitable advocates, facilitate communication, personalize the user experience, process payments, and communicate service updates or relevant promotions.',
        ]),
        LegalSection('3. Disclosure of Information', [
          'We may share necessary information with advocates or legal professionals to facilitate legal services; with service providers supporting platform operations, payments, or service delivery; and with authorities when required by law or necessary to protect our rights and interests.',
        ]),
        LegalSection('4. Payment and Fees', [
          'Advocates and users are required to make applicable payments for use of the platform. Registration, platform, or booking fees are non-refundable and cover access to and use of our services.',
        ]),
        LegalSection('5. Data Security', [
          'We use appropriate safeguards, including industry-standard security measures, to help prevent unauthorized access, disclosure, alteration, or destruction of personal information.',
        ]),
        LegalSection('Account Deletion', [
          'You can permanently delete your account from My profile or the navigation menu by choosing Delete account. Confirm your current password and type DELETE. Deletion removes your Firebase sign-in account and associated app data, including your profile, owned cases and uploaded files, consultation chats, reviews, saved advocates, and support history.',
          'Cases independently owned by other clients remain. Your consultation and related personal details are removed. Processing continues on our servers if you close the app, and failed cleanup attempts retry automatically. A minimal deletion-status record is kept temporarily to complete processing and prevent duplicate work.',
          'Account deletion does not cancel an Apple subscription or request a refund. Manage subscriptions through your Apple account settings. Files you exported or shared outside the app and records held independently by payment providers are not erased by deleting your app account.',
        ]),
        LegalSection('6. Changes to This Policy', [
          'We may modify this Privacy Policy at any time. Material changes may be announced on the platform or by email. Continued use after a change constitutes acceptance of the revised policy.',
        ]),
        LegalSection('7. Contact Us', [
          'Questions or concerns about this policy may be sent to:',
          'Address: Pune, Maharashtra\nPhone: 90042 97172, 90040 87172\nEmail: aapkelawyer@gmail.com\nWorking hours: 24 hours',
          'By using AAPKE LAWYER, you acknowledge that you have read, understood, and agree to be bound by this Privacy Policy.',
        ]),
        LegalSection('Refund & Cancellation Policy', [
          'The ₹249 advocate registration fee and ₹149 user platform fee are non-refundable. Once payment is successfully processed, no refund will be issued.',
          'A confirmation invoice will be sent to the email address supplied during registration or payment. Because services are rendered upon payment, cancellation is not applicable after payment and delivery of access.',
        ]),
        LegalSection('Shipping Policy', [
          'All AAPKE LAWYER services are digital. Services are made available after successful payment, and relevant documents such as invoices are delivered by email.',
          'Advocates receive listing access after payment of the registration fee. Users receive advocate contact details after payment of the platform fee.',
          'Confirmation and access are normally provided immediately after a successful transaction. For assistance, contact aapkelawyer@gmail.com or call 90040 87172 / 90042 97172.',
        ]),
        LegalSection('Pricing Policy', [
          'Advocates pay ₹249 as a registration amount. Users pay ₹149 as a platform fee.',
          'The user pays the platform fee only after an advocate accepts the case request. If a user pays one advocate and then pays another for the same request, AAPKE LAWYER is not responsible for the additional payment.',
        ]),
      ],
    );
  }
}
