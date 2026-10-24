import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/client_portal_surface.dart';
import '../../widgets/app_select_field.dart';
import '../models/support_models.dart';
import '../repositories/support_repository.dart';
import 'help_support_home_screen.dart';

class HelpSearchScreen extends StatefulWidget {
  const HelpSearchScreen({super.key, required this.repository});
  final SupportRepository repository;

  @override
  State<HelpSearchScreen> createState() => _HelpSearchScreenState();
}

class _HelpSearchScreenState extends State<HelpSearchScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help Center')),
    body: StreamBuilder<List<HelpArticle>>(
      stream: widget.repository.watchArticles(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final articles = snapshot.data!;
        final categories = ['All', ...articles.map((e) => e.category).toSet()];
        final query = _query.trim().toLowerCase();
        final filtered = articles.where((article) {
          final categoryMatches =
              _category == 'All' || article.category == _category;
          final searchText = [
            article.title,
            article.description,
            ...article.keywords,
          ].join(' ').toLowerCase();
          return categoryMatches &&
              (query.isEmpty || searchText.contains(query));
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search articles and keywords',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, index) => ChoiceChip(
                  label: Text(categories[index]),
                  selected: _category == categories[index],
                  onSelected: (_) =>
                      setState(() => _category = categories[index]),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyView(
                      icon: Icons.search_off,
                      message: 'No matching help articles.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final article = filtered[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.article_outlined),
                            title: Text(
                              article.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              article.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ClientPortalSurface(
                                  child: _ArticleScreen(article: article),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _ArticleScreen extends StatelessWidget {
  const _ArticleScreen({required this.article});
  final HelpArticle article;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help article')),
    body: SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(article.category, style: const TextStyle(color: kBrown)),
          const SizedBox(height: 8),
          Text(
            article.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(article.description, style: const TextStyle(color: kHint)),
          const Divider(height: 36),
          Text(
            article.content,
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Frequently Asked Questions')),
    body: StreamBuilder<List<SupportFaq>>(
      stream: widget.repository.watchFaqs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories = [
          'All',
          ...snapshot.data!.map((e) => e.category).toSet(),
        ];
        final filtered = snapshot.data!.where((faq) {
          final text = '${faq.question} ${faq.answer}'.toLowerCase();
          return (_category == 'All' || faq.category == _category) &&
              text.contains(_query.toLowerCase());
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search FAQs',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, i) => ChoiceChip(
                  label: Text(categories[i]),
                  selected: _category == categories[i],
                  onSelected: (_) => setState(() => _category = categories[i]),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyView(
                      icon: Icons.quiz_outlined,
                      message: 'No FAQs found.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => Card(
                        child: ExpansionTile(
                          title: Text(
                            filtered[i].question,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(filtered[i].category),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                filtered[i].answer,
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _description = TextEditingController();
  String _category = 'App functionality';
  String _severity = 'medium';
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_description.text.trim().length < 10) return;
    setState(() => _saving = true);
    try {
      await widget.repository.submitBug(
        description: _description.text,
        category: _category,
        severity: _severity,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Report a bug')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Describe what happened and what you expected.',
          style: TextStyle(color: kHint),
        ),
        const SizedBox(height: 16),
        AppSelectField<String>(
          label: 'Category',
          value: _category,
          options: const [
            'App functionality',
            'Payment',
            'Account',
            'Chat',
            'Other',
          ],
          itemLabel: (value) => value,
          onChanged: (value) => _category = value!,
        ),
        const SizedBox(height: 12),
        AppSelectField<String>(
          label: 'Severity',
          value: _severity,
          options: const ['low', 'medium', 'high', 'critical'],
          itemLabel: (value) => value.toUpperCase(),
          onChanged: (value) => _severity = value!,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 5,
          maxLines: 9,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(_saving ? 'Submitting...' : 'Submit bug report'),
        ),
      ],
    ),
  );
}

class FeatureRequestsScreen extends StatefulWidget {
  const FeatureRequestsScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<FeatureRequestsScreen> createState() => _FeatureRequestsScreenState();
}

class _FeatureRequestsScreenState extends State<FeatureRequestsScreen> {
  Future<void> _newFeature() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggest a feature'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (submit == true && title.text.trim().isNotEmpty) {
      await widget.repository.submitFeature(title.text, description.text);
    }
    title.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feature requests')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _newFeature,
      icon: const Icon(Icons.add),
      label: const Text('Suggest'),
    ),
    body: StreamBuilder(
      stream: widget.repository.watchFeatureRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorView(error: snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyView(
            icon: Icons.lightbulb_outline,
            message: 'Be the first to suggest a feature.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data();
            final votes = (data['votes'] as List? ?? const []).length;
            return Card(
              child: ListTile(
                title: Text(
                  (data['title'] ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text((data['description'] ?? '').toString()),
                trailing: TextButton.icon(
                  onPressed: () => widget.repository.voteFeature(docs[i].id),
                  icon: const Icon(Icons.arrow_upward, size: 17),
                  label: Text('$votes'),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contact us')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _ContactTile(
          Icons.email_outlined,
          'Email',
          'aapkelawyer@gmail.com',
          'mailto:aapkelawyer@gmail.com',
        ),
        _ContactTile(
          Icons.call_outlined,
          'Phone',
          '90040 87172',
          'tel:9004087172',
        ),
        _ContactTile(
          Icons.chat_outlined,
          'WhatsApp',
          'Chat with support',
          'https://wa.me/919004087172',
        ),
        _ContactTile(
          Icons.language,
          'Website',
          'Aapke Lawyer',
          'https://aapkelawyer.in',
        ),
      ],
    ),
  );
}

class _ContactTile extends StatelessWidget {
  const _ContactTile(this.icon, this.title, this.subtitle, this.url);
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => launchSupportUrl(context, url),
    ),
  );
}

class AppInformationScreen extends StatelessWidget {
  const AppInformationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('App information')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Icon(Icons.balance, size: 70, color: Colors.white),
        SizedBox(height: 14),
        Text(
          'Aapke Lawyer',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        Text(
          'Version 1.0.0 (1)',
          textAlign: TextAlign.center,
          style: TextStyle(color: kHint),
        ),
        SizedBox(height: 26),
        Text(
          'A platform for discovering, connecting with, and managing trusted legal assistance.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    ),
  );
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.repository});
  final SupportRepository repository;
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int rating = 5;
  final comment = TextEditingController();
  bool saving = false;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rate your experience')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'How was your experience?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => IconButton(
              onPressed: () => setState(() => rating = i + 1),
              icon: Icon(
                i < rating ? Icons.star : Icons.star_outline,
                color: Colors.amber,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: comment,
          minLines: 4,
          maxLines: 7,
          decoration: const InputDecoration(labelText: 'Comment (optional)'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() => saving = true);
                  await widget.repository.submitFeedback(rating, comment.text);
                  if (context.mounted) Navigator.pop(context);
                },
          child: Text(saving ? 'Submitting...' : 'Submit feedback'),
        ),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: kHint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kHint),
          ),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Could not load support content.\n$error',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
