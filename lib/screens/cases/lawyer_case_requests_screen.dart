import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/case_document.dart';
import '../../models/consultation_request.dart';
import '../../models/legal_case.dart';
import '../../repositories/case_repository.dart';
import '../../repositories/consultation_repository.dart';
import '../../services/app_error_message.dart';
import '../../widgets/client_portal_surface.dart';
import 'case_chat_screen.dart';

class LawyerCaseRequestsScreen extends StatefulWidget {
  const LawyerCaseRequestsScreen({
    super.key,
    this.initialStatus = ConsultationRequestStatus.pending,
  });

  final ConsultationRequestStatus initialStatus;

  @override
  State<LawyerCaseRequestsScreen> createState() =>
      _LawyerCaseRequestsScreenState();
}

class _LawyerCaseRequestsScreenState extends State<LawyerCaseRequestsScreen> {
  final ConsultationRepository _repository = ConsultationRepository();
  String? _updatingId;
  late ConsultationRequestStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  void didUpdateWidget(covariant LawyerCaseRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      _selectedStatus = widget.initialStatus;
    }
  }

  Future<void> _respond(
    ConsultationRequest request, {
    required bool accept,
  }) async {
    setState(() => _updatingId = request.id);
    try {
      await _repository.respond(request: request, accept: accept);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Case accepted.' : 'Request rejected.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(appErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _updatingId = null);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<ConsultationRequest>>(
    stream: _repository.watchLawyerRequests(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Requests could not be loaded: ${appErrorMessage(snapshot.error!)}',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final requests = snapshot.data!;
      const statusDetails =
          <ConsultationRequestStatus, ({String label, IconData icon})>{
            ConsultationRequestStatus.pending: (
              label: 'Pending',
              icon: Icons.hourglass_top_rounded,
            ),
            ConsultationRequestStatus.accepted: (
              label: 'Accepted',
              icon: Icons.verified_outlined,
            ),
            ConsultationRequestStatus.rejected: (
              label: 'Rejected',
              icon: Icons.cancel_outlined,
            ),
            ConsultationRequestStatus.completed: (
              label: 'Completed',
              icon: Icons.task_alt_outlined,
            ),
          };
      final selectedRequests = requests
          .where((item) => item.status == _selectedStatus)
          .toList();

      return Column(
        children: [
          Material(
            color: const Color(0xE638241C),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final status in ConsultationRequestStatus.values)
                    ChoiceChip(
                      selected: _selectedStatus == status,
                      showCheckmark: false,
                      avatar: Icon(statusDetails[status]!.icon, size: 17),
                      label: Text(
                        '${statusDetails[status]!.label} '
                        '${requests.where((item) => item.status == status).length}',
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedStatus = status),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_selectedStatus),
                child: _RequestList(
                  requests: selectedRequests,
                  updatingId: _updatingId,
                  onRespond: _respond,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    required this.updatingId,
    required this.onRespond,
  });
  final List<ConsultationRequest> requests;
  final String? updatingId;
  final Future<void> Function(
    ConsultationRequest request, {
    required bool accept,
  })
  onRespond;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'No cases here.',
          style: TextStyle(color: Color(0xFFD8C8BE)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) => LawyerRequestCard(
        request: requests[index],
        updating: updatingId == requests[index].id,
        onRespond: onRespond,
      ),
    );
  }
}

class LawyerRequestCard extends StatelessWidget {
  const LawyerRequestCard({
    super.key,
    required this.request,
    required this.updating,
    required this.onRespond,
  });
  final ConsultationRequest request;
  final bool updating;
  final Future<void> Function(
    ConsultationRequest request, {
    required bool accept,
  })
  onRespond;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      leading: const CircleAvatar(child: Icon(Icons.gavel)),
      title: Text(
        request.caseTitle,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('${request.clientName} • ${request.category}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(request.description, style: const TextStyle(height: 1.4)),
        ),
        const SizedBox(height: 12),
        _RequestDocuments(caseId: request.caseId),
        const SizedBox(height: 12),
        if (request.status == ConsultationRequestStatus.pending)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: updating
                      ? null
                      : () => onRespond(request, accept: false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: updating
                      ? null
                      : () => onRespond(request, accept: true),
                  child: updating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        if (request.status == ConsultationRequestStatus.accepted)
          StreamBuilder<LegalCase>(
            stream: CaseRepository().watchCase(request.caseId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Case status could not be loaded: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final paid = snapshot.data?.isPaidAndActive == true;
              if (!paid) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Accepted. Chat and calls unlock after the user pays the case fee.',
                    style: TextStyle(
                      color: Color(0xFFD8C8BE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return Row(
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
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Open Chat'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: request.clientPhone.isEmpty
                          ? null
                          : () => launchUrl(
                              Uri.parse('tel:${request.clientPhone}'),
                            ),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Call'),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    ),
  );
}

class _RequestDocuments extends StatelessWidget {
  const _RequestDocuments({required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CaseDocument>>(
    stream: CaseRepository().watchDocuments(caseId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Attachments could not be loaded: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          ),
        );
      }
      final documents = snapshot.data ?? const [];
      if (documents.isEmpty) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No attachments',
            style: TextStyle(color: Color(0xFFD8C8BE)),
          ),
        );
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
                        _openRequestDocument(context, document.downloadUrl),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('View Document'),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

Future<void> _openRequestDocument(
  BuildContext context,
  String downloadUrl,
) async {
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
