import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_back_app_bar.dart';

class LegalSection {
  const LegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

class LegalPolicyPage extends StatelessWidget {
  const LegalPolicyPage({
    super.key,
    required this.title,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final String introduction;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBackAppBar(title: title),
      body: SafeArea(
        top: false,
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kBrownDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to AAPKE LAWYER!',
                style: TextStyle(
                  color: kBrown,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(introduction, style: _bodyStyle),
              const SizedBox(height: 8),
              for (final section in sections) ...[
                const SizedBox(height: 22),
                Text(
                  section.title,
                  style: const TextStyle(
                    color: kBrownDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final paragraph in section.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(paragraph, style: _bodyStyle),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const _bodyStyle = TextStyle(
    color: kInk,
    fontSize: 15.5,
    height: 1.55,
  );
}
