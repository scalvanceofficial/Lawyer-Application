import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/case_document.dart';
import '../../models/case_timeline_event.dart';
import '../../models/consultation_request.dart';
import '../../models/legal_case.dart';
import '../../repositories/case_repository.dart';
import '../../repositories/consultation_repository.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/app_error_message.dart';
import '../../services/case_payment_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/client_portal_surface.dart';
import '../../widgets/app_select_field.dart';
import 'case_chat_screen.dart';

class CaseDetailScreen extends StatelessWidget {
  CaseDetailScreen({super.key, required this.legalCase});

  final LegalCase legalCase;
  final CaseRepository _cases = CaseRepository();
  final ConsultationRepository _consultations = ConsultationRepository();

  Future<void> _unlock(BuildContext context) async {
    try {
      final profile = await AuthService.currentUserProfile(UserRole.client);
      await CasePaymentService().activateCase(
        legalCase: legalCase,
        clientName: profile.displayName,
        email: profile.email,
        phone: profile.phone,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case activated successfully.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
    }
  }

  Future<void> _review(
    BuildContext context,
    List<ConsultationRequest> acceptedRequests,
  ) async {
    if (acceptedRequests.isEmpty) return;
    final review = await showDialog<_CaseReviewDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompleteCaseDialog(
        caseTitle: legalCase.title,
        acceptedRequests: acceptedRequests,
      ),
    );
    if (review == null || !context.mounted) return;

    try {
      await _cases.submitLawyerReview(
        caseId: legalCase.id,
        requestId: review.request.id,
        lawyerId: review.request.lawyerId,
        lawyerName: review.request.lawyerName,
        rating: review.rating,
        review: review.review,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review submitted.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
    }
  }

  Future<void> _markCompleted(BuildContext context) async {
    try {
      await _cases.markCaseCompleted(legalCase.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Case marked completed.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(legalCase.title)),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        StreamBuilder<List<ConsultationRequest>>(
          stream: _consultations.watchClientRequests(caseId: legalCase.id),
          builder: (context, snapshot) {
            final accepted = (snapshot.data ?? const <ConsultationRequest>[])
                .where(
                  (item) => item.status == ConsultationRequestStatus.accepted,
                )
                .toList();
            return _CaseSummary(
              legalCase: legalCase,
              canUnlock: accepted.isNotEmpty,
              canComplete: legalCase.isPaidAndActive && accepted.isNotEmpty,
              onUnlock: () => _unlock(context),
              onComplete: () => _markCompleted(context),
            );
          },
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Requested Advocates'),
        StreamBuilder<List<ConsultationRequest>>(
          stream: _consultations.watchClientRequests(caseId: legalCase.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EmptyText(
                'Advocate requests could not be loaded: '
                '${appErrorMessage(snapshot.error!)}',
              );
            }
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return const _EmptyText('No advocate requests yet.');
            }
            return Column(
              children: requests
                  .map(
                    (request) => _LawyerRequestCard(
                      request: request,
                      casePaid: legalCase.isPaidAndActive,
                      onReview:
                          request.status ==
                                  ConsultationRequestStatus.accepted &&
                              legalCase.isPaidAndActive
                          ? () => _review(context, [request])
                          : null,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Documents'),
        StreamBuilder<List<CaseDocument>>(
          stream: _cases.watchDocuments(legalCase.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _EmptyText(
                'Documents could not be loaded: ${snapshot.error}',
              );
            }
            final documents = snapshot.data ?? const [];
            if (documents.isEmpty) {
              return const _EmptyText('No documents uploaded.');
            }
            return Column(
              children: documents
                  .map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openDocument(context, document.downloadUrl),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('View Document'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Timeline'),
        StreamBuilder<List<CaseTimelineEvent>>(
          stream: _cases.watchTimeline(legalCase.id),
          builder: (context, snapshot) {
            final events = snapshot.data ?? const [];
            if (events.isEmpty) return const _EmptyText('No activity yet.');
            return Column(
              children: events
                  .map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 16,
                        child: Icon(Icons.history, size: 17),
                      ),
                      title: Text(event.message),
                      subtitle: Text(_date(event.createdAt)),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _CaseSummary extends StatelessWidget {
  const _CaseSummary({
    required this.legalCase,
    required this.canUnlock,
    required this.canComplete,
    required this.onUnlock,
    required this.onComplete,
  });
  final LegalCase legalCase;
  final bool canUnlock;
  final bool canComplete;
  final VoidCallback onUnlock;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  legalCase.category,
                  style: const TextStyle(
                    color: kBrown,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Chip(
                avatar: Icon(
                  legalCase.isPaidAndActive ? Icons.verified : Icons.lock,
                  size: 17,
                ),
                label: Text(
                  legalCase.isPaidAndActive
                      ? 'Paid & Active'
                      : canUnlock
                      ? 'Accepted • Payment due'
                      : 'Awaiting advocate',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(legalCase.description, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 10),
          Text(
            legalCase.isPaidAndActive
                ? '₹149 platform fee paid permanently for this case.'
                : canUnlock
                ? 'An advocate accepted. Pay once to unlock chat and calls for this case.'
                : 'No payment is due until an advocate accepts.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (!legalCase.isPaidAndActive && canUnlock) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock this Case • ₹149'),
              ),
            ),
          ] else if (canComplete &&
              legalCase.status != LegalCaseStatus.completed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.task_alt),
                label: const Text('Mark Case Completed'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CaseReviewDraft {
  const _CaseReviewDraft({
    required this.request,
    required this.rating,
    required this.review,
  });
  final ConsultationRequest request;
  final int rating;
  final String review;
}

class _CompleteCaseDialog extends StatefulWidget {
  const _CompleteCaseDialog({
    required this.caseTitle,
    required this.acceptedRequests,
  });
  final String caseTitle;
  final List<ConsultationRequest> acceptedRequests;

  @override
  State<_CompleteCaseDialog> createState() => _CompleteCaseDialogState();
}

class _CompleteCaseDialogState extends State<_CompleteCaseDialog> {
  final _review = TextEditingController();
  late ConsultationRequest _lawyer = widget.acceptedRequests.first;
  int _rating = 0;
  String? _error;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _review.text.trim();
    if (_rating == 0 || text.length < 3) {
      setState(() {
        _error = _rating == 0
            ? 'Choose a star rating.'
            : 'Write a short review (at least 3 characters).';
      });
      return;
    }
    Navigator.pop(
      context,
      _CaseReviewDraft(request: _lawyer, rating: _rating, review: text),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.rate_review_outlined, size: 38, color: Colors.white),
    title: const Text('Rate and review advocate'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share your experience with the advocate for "${widget.caseTitle}".',
          ),
          if (widget.acceptedRequests.length > 1) ...[
            const SizedBox(height: 16),
            AppSelectField<ConsultationRequest>(
              label: 'Advocate to review',
              value: _lawyer,
              options: widget.acceptedRequests,
              itemLabel: (request) => request.lawyerName,
              onChanged: (value) {
                if (value != null) setState(() => _lawyer = value);
              },
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              _lawyer.lawyerName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                tooltip: '$value star${value == 1 ? '' : 's'}',
                onPressed: () => setState(() {
                  _rating = value;
                  _error = null;
                }),
                icon: Icon(
                  value <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                ),
              );
            }),
          ),
          TextField(
            controller: _review,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Review',
              hintText: 'How was your experience with this advocate?',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Submit Review')),
    ],
  );
}

class _LawyerRequestCard extends StatelessWidget {
  const _LawyerRequestCard({
    required this.request,
    required this.casePaid,
    required this.onReview,
  });
  final ConsultationRequest request;
  final bool casePaid;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.balance)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  request.lawyerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          if (request.status == ConsultationRequestStatus.accepted &&
              casePaid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientPortalSurface(
                          child: CaseChatScreen(request: request),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: request.lawyerPhone.isEmpty
                        ? null
                        : () => launchUrl(
                            Uri.parse('tel:${request.lawyerPhone}'),
                          ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.star_rate_rounded),
                label: const Text('Rate & Review This Advocate'),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Available because this advocate accepted your request and the case fee is paid.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFFD8C8BE)),
            ),
          ] else if (request.status == ConsultationRequestStatus.accepted) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Accepted. Pay the one-time case fee above to unlock chat, calls, and the verified rating option.',
                style: TextStyle(
                  color: Color(0xFFD8C8BE),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ConsultationRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConsultationRequestStatus.accepted => Colors.green,
      ConsultationRequestStatus.rejected => Colors.red,
      ConsultationRequestStatus.completed => Colors.blueGrey,
      ConsultationRequestStatus.pending => Colors.orange,
    };
    return Chip(
      label: Text(status.name),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(text, style: const TextStyle(color: Color(0xFFD8C8BE))),
  );
}

String _date(DateTime date) =>
    '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

Future<void> _openDocument(BuildContext context, String downloadUrl) async {
  try {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('This document link is invalid.');
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw StateError('No application could open this document.');
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Document could not be opened: ${appErrorMessage(error)}',
        ),
      ),
    );
  }
}
