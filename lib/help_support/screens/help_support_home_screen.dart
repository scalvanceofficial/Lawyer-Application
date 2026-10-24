import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/client_portal_surface.dart';
import '../repositories/support_repository.dart';
import 'support_content_screens.dart';
import 'support_ticket_screens.dart';

class HelpSupportHomeScreen extends StatelessWidget {
  const HelpSupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = SupportRepository();
    final items = <_SupportDestination>[
      _SupportDestination(
        Icons.search,
        'Search Help',
        'Find answers in our Help Center',
        (_) => HelpSearchScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.quiz_outlined,
        'Frequently Asked Questions',
        'Browse common questions by category',
        (_) => FaqScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.add_comment_outlined,
        'Raise Support Ticket',
        'Tell our support team what happened',
        (_) => CreateTicketScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.confirmation_number_outlined,
        'My Tickets',
        'Track requests, replies, and status',
        (_) => MyTicketsScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.forum_outlined,
        'Chat with Support',
        'Continue a conversation on your ticket',
        (_) => MyTicketsScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.bug_report_outlined,
        'Report Bug',
        'Report a technical problem',
        (_) => BugReportScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.lightbulb_outline,
        'Suggest Feature',
        'Share and vote on product ideas',
        (_) => FeatureRequestsScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.contact_support_outlined,
        'Contact Us',
        'Email, phone, WhatsApp, or website',
        (_) => const ContactSupportScreen(),
      ),
      _SupportDestination(
        Icons.menu_book_outlined,
        'User Guide',
        'Learn how to use Aapke Lawyer',
        (_) => HelpSearchScreen(repository: repository),
      ),
      _SupportDestination(
        Icons.info_outline,
        'App Information',
        'Version, policies, and service details',
        (_) => const AppInformationScreen(),
      ),
      _SupportDestination(
        Icons.star_outline,
        'Rate App',
        'Tell us about your experience',
        (_) => FeedbackScreen(repository: repository),
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async =>
          Future<void>.delayed(const Duration(milliseconds: 350)),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            sliver: SliverList.list(
              children: [
                const Text(
                  'How can we help?',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Find an answer or connect with our support team.',
                  style: TextStyle(color: Color(0xFFD8C8BE), fontSize: 15),
                ),
                const SizedBox(height: 16),
                _SystemStatus(repository: repository),
                _Announcements(repository: repository),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            sliver: SliverGrid.builder(
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 112,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) => _SupportCard(
                destination: items[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ClientPortalSurface(
                      child: items[index].builder(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemStatus extends StatelessWidget {
  const _SystemStatus({required this.repository});
  final SupportRepository repository;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: repository.watchSystemStatus(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? const [];
      final data = docs.isEmpty ? null : docs.first.data();
      final status = (data?['status'] ?? 'operational')
          .toString()
          .toLowerCase();
      final color = status == 'outage'
          ? Colors.red
          : status == 'maintenance'
          ? Colors.orange
          : Colors.green;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, size: 11, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                data?['message']?.toString().isNotEmpty == true
                    ? data!['message'].toString()
                    : status == 'operational'
                    ? 'All systems operational'
                    : 'Service status: $status',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Announcements extends StatelessWidget {
  const _Announcements({required this.repository});
  final SupportRepository repository;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: repository.watchAnnouncements(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? const [];
      if (docs.isEmpty) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.only(top: 10),
        child: ListTile(
          leading: const Icon(Icons.campaign_outlined, color: kBrown),
          title: Text(
            (docs.first.data()['title'] ?? 'Announcement').toString(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            (docs.first.data()['description'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    },
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.destination, required this.onTap});
  final _SupportDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8C8A7).withValues(alpha: .16),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(destination.icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    destination.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD8C8BE),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFD8C8BE)),
          ],
        ),
      ),
    ),
  );
}

class _SupportDestination {
  const _SupportDestination(this.icon, this.title, this.subtitle, this.builder);
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

Future<void> launchSupportUrl(BuildContext context, String url) async {
  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}
